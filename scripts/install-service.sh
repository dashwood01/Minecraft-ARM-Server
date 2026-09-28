#!/usr/bin/env bash
# Install the systemd units so the server starts at boot (headless).
# Usage: sudo ./scripts/install-service.sh [--bds-dir DIR] [user]
#   --bds-dir DIR  Official BDS directory (default: <user's home>/minecraft-bedrock-server)
#   user           Account that runs the server (default: owner of --bds-dir if
#                  given, otherwise owner of this project directory)
set -euo pipefail

die() { echo "ERROR: $*" >&2; exit 1; }

BDS_DIR_ARG=""
RUN_USER=""
while [ $# -gt 0 ]; do
    case "$1" in
        --bds-dir) [ $# -ge 2 ] || die "--bds-dir needs a directory"; BDS_DIR_ARG="$2"; shift ;;
        -h|--help) sed -n '2,6p' "$0"; exit 0 ;;
        -*) die "unknown option: $1" ;;
        *) RUN_USER="$1" ;;
    esac
    shift
done

[ "$(id -u)" -eq 0 ] || die "run with sudo"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ -n "$BDS_DIR_ARG" ]; then
    [ -d "$BDS_DIR_ARG" ] || die "BDS directory '$BDS_DIR_ARG' does not exist"
    BDS_DIR="$(cd "$BDS_DIR_ARG" && pwd)"
    RUN_USER="${RUN_USER:-$(stat -c %U "$BDS_DIR")}"
else
    RUN_USER="${RUN_USER:-$(stat -c %U "$PROJECT_DIR")}"
fi
id "$RUN_USER" >/dev/null 2>&1 || die "user $RUN_USER does not exist"
[ "$RUN_USER" != "root" ] || die "refusing to run the server as root; pass a normal user"

if [ -z "$BDS_DIR_ARG" ]; then
    RUN_HOME="$(getent passwd "$RUN_USER" | cut -d: -f6)"
    BDS_DIR="$RUN_HOME/minecraft-bedrock-server"
fi

[ -d "$BDS_DIR" ] || die "BDS directory '$BDS_DIR' does not exist.
       Extract the official Linux Bedrock Dedicated Server there, or pass --bds-dir DIR."
[ -f "$BDS_DIR/bedrock_server" ] || die "bedrock_server not found in '$BDS_DIR'"
case "$BDS_DIR/" in
    "$PROJECT_DIR"/*) die "BDS directory is inside the project repository; keep the official server files in a separate directory" ;;
esac

# The paths are substituted into unit files; keep them free of characters that
# systemd or sed would interpret.
for d in "$PROJECT_DIR" "$BDS_DIR"; do
    [[ "$d" =~ ^[A-Za-z0-9._/+@-]+$ ]] || die "path '$d' contains spaces or special characters; move it to a simple path"
done

runuser -u "$RUN_USER" -- test -w "$BDS_DIR" \
    || echo "WARNING: $RUN_USER cannot write to $BDS_DIR; the server needs write access (worlds, logs)." >&2

for unit in bedrock.socket bedrock.service; do
    sed -e "s|@USER@|$RUN_USER|g" -e "s|@DIR@|$PROJECT_DIR|g" -e "s|@BDS_DIR@|$BDS_DIR|g" \
        "$PROJECT_DIR/systemd/$unit" > "/etc/systemd/system/$unit"
    echo "Installed /etc/systemd/system/$unit"
done
chmod +x "$PROJECT_DIR"/scripts/*.sh "$BDS_DIR/bedrock_server"

systemctl daemon-reload
systemctl enable bedrock.socket bedrock.service
echo
echo "User:        $RUN_USER"
echo "BDS_DIR:     $BDS_DIR"
echo "Start now:   sudo systemctl start bedrock"
echo "Logs:        journalctl -u bedrock -f"
echo "Command:     $PROJECT_DIR/scripts/console.sh list"
echo "Stop:        sudo systemctl stop bedrock   (sends 'stop', waits for save)"
