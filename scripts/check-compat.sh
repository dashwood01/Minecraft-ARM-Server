#!/usr/bin/env bash
# Pre-flight check: is this machine ready to run the Bedrock server on ARM64?
# Exit status: 0 = all required checks passed, 1 = at least one FAIL.
set -uo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../arm64.env
. "$PROJECT_DIR/arm64.env"

FAILS=0
pass() { printf '  [PASS] %s\n' "$*"; }
warn() { printf '  [WARN] %s\n' "$*"; }
fail() { printf '  [FAIL] %s\n' "$*"; FAILS=$((FAILS+1)); }

echo "Bedrock ARM64 compatibility check"
echo "  Project: $PROJECT_DIR"
echo "  BDS_DIR: $BDS_DIR"

MODEL="$(tr -d '\0' 2>/dev/null < /proc/device-tree/model || echo unknown)"
echo "  Board: $MODEL"

ARCH="$(uname -m)"
[ "$ARCH" = "aarch64" ] && pass "64-bit ARM kernel ($ARCH)" || fail "kernel is $ARCH, need aarch64"

if command -v dpkg >/dev/null; then
    UA="$(dpkg --print-architecture)"
    [ "$UA" = "arm64" ] && pass "64-bit userland ($UA)" || fail "userland is $UA, need arm64 (Raspberry Pi OS Lite 64-bit)"
fi

PS="$(getconf PAGESIZE)"
[ "$PS" = "4096" ] && pass "4K page size" \
    || warn "page size $PS: use the 4K kernel (kernel=kernel8.img in /boot/firmware/config.txt) for best Box64 compatibility"

if [ -x "$BOX64_BIN" ]; then
    pass "Box64: $("$BOX64_BIN" --version 2>/dev/null | head -1)"
else
    fail "Box64 missing at $BOX64_BIN (run: sudo ./scripts/install-deps.sh)"
fi

[ -f /usr/lib/box64-x86_64-linux-gnu/libgcc_s.so.1 ] \
    && pass "x86_64 libgcc_s.so.1 provided by Box64" \
    || fail "/usr/lib/box64-x86_64-linux-gnu/libgcc_s.so.1 missing (Box64 not installed with 'make install')"

# --- Official server files (user-provided, outside this repository) -----------
if [ -d "$BDS_DIR" ]; then
    pass "BDS_DIR exists"
    case "$BDS_DIR/" in
        "$PROJECT_DIR"/*) warn "BDS_DIR is inside the project repository; keep the official server files in a separate directory" ;;
    esac
    [ -w "$BDS_DIR" ] || warn "BDS_DIR is not writable by $(id -un); the server must be able to write worlds and logs there"
else
    fail "BDS_DIR '$BDS_DIR' missing: extract the official Linux BDS there, or set BDS_DIR"
fi

BIN="$BDS_DIR/bedrock_server"
if [ -f "$BIN" ]; then
    # ELF e_machine at offset 18: 0x3e = x86_64
    MACH="$(od -An -tx1 -j18 -N2 "$BIN" | tr -d ' ')"
    [ "$MACH" = "3e00" ] && pass "bedrock_server is an x86_64 ELF (runs via Box64)" \
        || warn "bedrock_server e_machine=0x$MACH (unexpected)"
    [ -x "$BIN" ] || warn "bedrock_server not executable (start.sh fixes this)"
else
    fail "bedrock_server missing in BDS_DIR"
fi

MEM_MB=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)
SWAP_MB=$(awk '/SwapTotal/ {print int($2/1024)}' /proc/meminfo)
if   [ "$MEM_MB" -ge 3500 ]; then pass "RAM ${MEM_MB} MiB"
elif [ "$MEM_MB" -ge 1800 ]; then warn "RAM ${MEM_MB} MiB: works for a few players; lower view-distance"
else fail "RAM ${MEM_MB} MiB: at least 2 GiB (4 GiB+ recommended) is needed"; fi
[ "$SWAP_MB" -ge 1024 ] || warn "swap ${SWAP_MB} MiB: 1-2 GiB swap recommended as a safety net"

PROPS="$BDS_DIR/server.properties"
if [ -f "$PROPS" ]; then
    for p in $(awk -F= '/^server-port(v6)?=/ {print $2}' "$PROPS"); do
        if command -v ss >/dev/null && ss -Hlun "sport = :$p" | grep -q .; then
            warn "UDP port $p already in use (another server running?)"
        else
            pass "UDP port $p free"
        fi
    done
else
    warn "server.properties not found in BDS_DIR; port check skipped"
fi

DISK_DIR="$BDS_DIR"; [ -d "$DISK_DIR" ] || DISK_DIR="$PROJECT_DIR"
FREE_MB=$(df -Pm "$DISK_DIR" | awk 'NR==2 {print $4}')
[ "$FREE_MB" -ge 2048 ] && pass "disk free ${FREE_MB} MiB" || warn "disk free ${FREE_MB} MiB (worlds + DynaCache need space)"

echo
[ "$FAILS" -eq 0 ] && echo "Result: ready." || echo "Result: $FAILS required check(s) failed."
[ "$FAILS" -eq 0 ]
