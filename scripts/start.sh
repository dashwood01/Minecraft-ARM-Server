#!/usr/bin/env bash
# Start the Bedrock Dedicated Server on ARM64 through Box64.
# Runs in the foreground; type server commands (e.g. "stop") on stdin.
# The official server files are read from $BDS_DIR (see arm64.env).
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../arm64.env
. "$PROJECT_DIR/arm64.env"

die() { echo "ERROR: $*" >&2; exit 1; }

[ -d "$BDS_DIR" ] || die "BDS_DIR '$BDS_DIR' does not exist.
       Download the official Linux Bedrock Dedicated Server from
       https://www.minecraft.net/en-us/download/server/bedrock and extract it there,
       or set BDS_DIR (environment or arm64.env) to where you extracted it."
[ -f "$BDS_DIR/bedrock_server" ] || die "bedrock_server not found in BDS_DIR '$BDS_DIR'.
       Extract the official Linux Bedrock Dedicated Server into that directory."

# BDS reads server.properties, worlds/ etc. from its working directory.
cd "$BDS_DIR"

if [ "$(uname -m)" = "x86_64" ] && [ "${BDS_FORCE_BOX64:-0}" != "1" ]; then
    # Same behaviour as the official server on a PC: run natively.
    # (BDS_FORCE_BOX64=1 forces the Box64 path, for testing under qemu-user.)
    exec env LD_LIBRARY_PATH=. ./bedrock_server
fi

command -v "$BOX64_BIN" >/dev/null 2>&1 || \
    die "Box64 not found at $BOX64_BIN. Run: sudo $PROJECT_DIR/scripts/install-deps.sh"
[ -x ./bedrock_server ] || chmod +x ./bedrock_server
mkdir -p "$BOX64_DYNACACHE_FOLDER"

exec "$BOX64_BIN" ./bedrock_server
