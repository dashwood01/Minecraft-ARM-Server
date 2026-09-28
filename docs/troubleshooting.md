# Troubleshooting

| Symptom | Cause and fix |
|---|---|
| `ERROR: BDS_DIR '...' does not exist` | The official server isn't where the scripts look. Extract the Linux BDS into `~/minecraft-bedrock-server`, or set `BDS_DIR` ([configuration.md](configuration.md)) |
| `ERROR: bedrock_server not found in BDS_DIR '...'` | `BDS_DIR` points at the wrong directory, for example one level too high after unzipping into a subfolder. Point it at the directory that directly contains `bedrock_server` |
| `[WARN] BDS_DIR is inside the project repository` or `install-service.sh` refuses | Move the server files to a separate directory. They must not live in the Git repository |
| `[WARN] BDS_DIR is not writable` | Give the user that runs the server ownership of the directory, for example `sudo chown -R <user>: ~/minecraft-bedrock-server` |
| `ERROR: kernel architecture is armv7l ...` or `userland is armhf` | The OS is 32-bit. Reinstall with **Raspberry Pi OS Lite (64-bit)** |
| `ERROR: run with sudo` | Run `install-deps.sh` and `install-service.sh` with `sudo` |
| `ERROR: Box64 not found at /usr/local/bin/box64` | Run `sudo ./scripts/install-deps.sh` |
| `Error loading needed lib libgcc_s.so.1` | Box64 was copied instead of installed. Run `sudo make install` in `/usr/local/src/box64-0.4.4/build` |
| `cannot execute binary file: Exec format error` | You ran `bedrock_server` directly. Use `scripts/start.sh` |
| Crash right at startup on a Pi 5 | Run `getconf PAGESIZE`. If it prints `16384`, run `install-deps.sh --fix-pagesize` (or add `kernel=kernel8.img`) and reboot |
| Random crashes or hangs under load | Set `BOX64_DYNAREC_STRONGMEM=1` in `arm64.env`, then `2` |
| Log shows "Your current connection type is not set to NetherNet" and players can't connect | Set `transport=nethernet` in `server.properties`. This is a BDS setting, unrelated to the ARM port |
| `[WARN] UDP port 19132 already in use` | Another server is running. Check with `ss -lunp`, or change `server-port` |
| Server killed, or `dmesg` shows `Out of memory` | Lower `view-distance`, add 1–2 GB of swap, or use a board with more RAM |
| Client or server reports the other side as outdated | Versions differ. Update BDS ([installation.md](installation.md#updating)) |
| `ERROR: /run/bedrock/console not found; is bedrock.socket running?` | The service isn't installed or running. Run `sudo systemctl start bedrock` |
| `install-service.sh`: `path '...' contains spaces or special characters` | Move the repository or the server directory to a path made only of letters, digits and `._/+@-` |
| First start takes several minutes | Expected: Box64 is translating the binary. Keep `$BDS_DIR/.box64-cache/` |

## Memory and swap

On a board with 2–4 GB of RAM, set up 1–2 GB of swap:

- **bookworm:** set `CONF_SWAPSIZE=2048` in `/etc/dphys-swapfile`, then run
  `sudo systemctl restart dphys-swapfile`.
- **trixie:** swap is managed differently. See the Raspberry Pi documentation.

## Collecting diagnostics

```bash
./scripts/check-compat.sh
uname -a; getconf PAGESIZE; free -m
box64 --version
journalctl -u bedrock -n 200 --no-pager       # service mode
```

For more Box64 detail, set `BOX64_LOG=1` in `arm64.env` and restart. Before you share
logs, remove player names, IP addresses and anything else private.
