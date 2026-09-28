#!/usr/bin/env bash
# Install system packages and build Box64 natively on Raspberry Pi OS Lite (64-bit).
#
# Usage: sudo ./scripts/install-deps.sh [--fix-pagesize] [--jobs N]
#   --fix-pagesize  On a Pi 5 running the 16K-page kernel, switch to the 4K-page
#                   kernel (edits /boot/firmware/config.txt, reboot required).
#   --jobs N        Parallel compile jobs (default: based on RAM).
set -euo pipefail

BOX64_VERSION="v0.4.4"   # version this project was verified with
BOX64_URL="https://github.com/ptitSeb/box64/archive/refs/tags/${BOX64_VERSION}.tar.gz"
BUILD_ROOT="/usr/local/src"

FIX_PAGESIZE=0
JOBS=""
while [ $# -gt 0 ]; do
    case "$1" in
        --fix-pagesize) FIX_PAGESIZE=1 ;;
        --jobs) JOBS="$2"; shift ;;
        -h|--help) sed -n '2,8p' "$0"; exit 0 ;;
        *) echo "Unknown option: $1" >&2; exit 2 ;;
    esac
    shift
done

die() { echo "ERROR: $*" >&2; exit 1; }
log() { echo "==> $*"; }

[ "$(id -u)" -eq 0 ] || die "run with sudo"
[ "$(uname -m)" = "aarch64" ] || die "kernel architecture is $(uname -m); a 64-bit (aarch64) kernel is required"
[ "$(dpkg --print-architecture)" = "arm64" ] || die "userland is $(dpkg --print-architecture); install Raspberry Pi OS Lite (64-bit)"

MODEL="$(tr -d '\0' 2>/dev/null < /proc/device-tree/model || echo unknown)"
log "Detected: $MODEL"

case "$MODEL" in
    *"Raspberry Pi 5"*|*"Compute Module 5"*|*"Raspberry Pi 500"*) BOX64_PROFILE="-DRPI5ARM64=1" ;;
    *"Raspberry Pi 4"*|*"Compute Module 4"*|*"Raspberry Pi 400"*) BOX64_PROFILE="-DRPI4ARM64=1" ;;
    *"Raspberry Pi 3"*|*"Zero 2"*)  BOX64_PROFILE="-DRPI3ARM64=1" ;;
    *) BOX64_PROFILE="-DARM_DYNAREC=ON"
       echo "WARNING: not a recognised Raspberry Pi; using a generic ARM64 Box64 build." ;;
esac

# --- Page size ---------------------------------------------------------------
PAGESIZE="$(getconf PAGESIZE)"
if [ "$PAGESIZE" != "4096" ]; then
    echo "WARNING: kernel page size is $PAGESIZE bytes. Box64 is most compatible with 4K pages."
    CONFIG_TXT=/boot/firmware/config.txt
    [ -f "$CONFIG_TXT" ] || CONFIG_TXT=/boot/config.txt
    if [ "$FIX_PAGESIZE" -eq 1 ]; then
        if grep -q '^kernel=kernel8.img' "$CONFIG_TXT"; then
            log "kernel=kernel8.img already set in $CONFIG_TXT (reboot pending?)"
        else
            cp "$CONFIG_TXT" "$CONFIG_TXT.bak.$(date +%Y%m%d%H%M%S)"
            printf '\n[all]\n# 4K-page kernel for Box64 (Bedrock server)\nkernel=kernel8.img\n' >> "$CONFIG_TXT"
            log "Added kernel=kernel8.img to $CONFIG_TXT (backup saved). Reboot after this script finishes."
        fi
    else
        echo "         Re-run with --fix-pagesize, or add 'kernel=kernel8.img' to /boot/firmware/config.txt and reboot."
    fi
fi

# --- Packages -----------------------------------------------------------------
# Box64 build: git-free tarball build needs cmake, a C toolchain and python3.
# Server runtime: nothing extra (BDS only needs libc/libm/libdl/libpthread/librt,
# which Box64 maps to the native ARM64 glibc, and libgcc_s, which Box64 ships).
log "Installing packages"
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    build-essential cmake python3 curl ca-certificates unzip

# --- Build Box64 ----------------------------------------------------------------
if [ -z "$JOBS" ]; then
    MEM_MB=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)
    if   [ "$MEM_MB" -lt 1500 ]; then JOBS=1
    elif [ "$MEM_MB" -lt 3000 ]; then JOBS=2
    else JOBS=$(nproc); fi
fi

SRC="$BUILD_ROOT/box64-${BOX64_VERSION#v}"
log "Building Box64 $BOX64_VERSION ($BOX64_PROFILE, $JOBS jobs) in $SRC"
mkdir -p "$BUILD_ROOT"
rm -rf "$SRC"
curl -fsSL "$BOX64_URL" | tar -xz -C "$BUILD_ROOT"
mkdir -p "$SRC/build"
cd "$SRC/build"
cmake .. $BOX64_PROFILE -DCMAKE_BUILD_TYPE=RelWithDebInfo
make -j"$JOBS"
# 'make install' matters: it also installs the x86_64 libgcc_s.so.1 that
# bedrock_server links against into /usr/lib/box64-x86_64-linux-gnu.
make install
systemctl restart systemd-binfmt 2>/dev/null || true

# --- Verify -------------------------------------------------------------------
log "Verifying"
/usr/local/bin/box64 --version
[ -f /usr/lib/box64-x86_64-linux-gnu/libgcc_s.so.1 ] || die "libgcc_s.so.1 for x86_64 missing"
log "Done. Next: extract the official Linux BDS into \$BDS_DIR (default ~/minecraft-bedrock-server), then ./scripts/check-compat.sh and ./scripts/start.sh"
