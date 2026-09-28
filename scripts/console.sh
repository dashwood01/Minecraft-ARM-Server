#!/usr/bin/env bash
# Send a command to the server when it runs as the systemd service.
# Usage: ./scripts/console.sh say hello      |   ./scripts/console.sh list
# Output appears in: journalctl -u bedrock -f
set -euo pipefail
FIFO=/run/bedrock/console
[ $# -gt 0 ] || { echo "Usage: $0 <server command>" >&2; exit 2; }
[ -p "$FIFO" ] || { echo "ERROR: $FIFO not found; is bedrock.socket running?" >&2; exit 1; }
printf '%s\n' "$*" > "$FIFO"
