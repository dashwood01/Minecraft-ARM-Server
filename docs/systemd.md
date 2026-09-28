# Running as a systemd service

## Install

```bash
cd ~/bedrock_arm_public
sudo ./scripts/install-service.sh --bds-dir ~/minecraft-bedrock-server
sudo systemctl start bedrock
```

`install-service.sh` does the following:

1. It picks the run user and `BDS_DIR` (see [configuration.md](configuration.md)). It
   refuses to run the server as `root`.
2. It checks that:
   - `BDS_DIR` exists and contains `bedrock_server`.
   - `BDS_DIR` isn't inside the repository.
   - Neither path contains spaces or special characters.
   - The run user can write to `BDS_DIR`. A failure here produces only a warning.
3. It replaces `@USER@`, `@DIR@` (the repository) and `@BDS_DIR@` in `systemd/*` and
   writes the results to `/etc/systemd/system/`.
4. It marks the scripts and `bedrock_server` as executable, then runs
   `systemctl daemon-reload` and
   `systemctl enable bedrock.socket bedrock.service`.

No files are copied to `/usr/local` or `/opt`. The service runs `start.sh` from the
repository and the server from `BDS_DIR`.

## Everyday commands

| Task | Command |
|---|---|
| Start | `sudo systemctl start bedrock` |
| Stop cleanly | `sudo systemctl stop bedrock` |
| Restart | `sudo systemctl restart bedrock` |
| Status | `systemctl status bedrock` |
| Live log and console output | `journalctl -u bedrock -f` |
| Send a console command | `./scripts/console.sh list` or `./scripts/console.sh say Restarting soon` |
| Disable autostart | `sudo systemctl disable bedrock bedrock.socket` |

## How it works

- **`bedrock.socket`** creates a FIFO at `/run/bedrock/console`, owned by the run user
  with mode `0660`. The FIFO becomes the server's standard input.
- **`console.sh`** writes one command line into that FIFO. The output appears in the
  journal.
- **`bedrock.service`** sets `Environment=BDS_DIR=...` and
  `WorkingDirectory=<BDS_DIR>`, runs `scripts/start.sh`, and sends its output to the
  journal.
- On stop, **`ExecStop`** writes `stop` to the FIFO and waits for the process to exit,
  so the world is always saved. `TimeoutStopSec=120` limits the wait.
- **`Restart=on-failure`** restarts the server 15 s after a crash, but not after a
  normal `stop`.

## Changing `BDS_DIR` or moving the repository

Run `install-service.sh` again with the new `--bds-dir`. It overwrites the installed
units and reloads systemd. Then restart the service:

```bash
sudo ./scripts/install-service.sh --bds-dir /new/path
sudo systemctl restart bedrock
```

## Uninstall

```bash
sudo systemctl disable --now bedrock.service bedrock.socket
sudo rm /etc/systemd/system/bedrock.service /etc/systemd/system/bedrock.socket
sudo systemctl daemon-reload
```

Uninstalling doesn't touch your server directory or worlds.
