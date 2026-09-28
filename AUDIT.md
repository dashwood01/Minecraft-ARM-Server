# Repository audit

This document records what the public repository contains, what it deliberately
leaves out, and why.

## Architecture

```text
bedrock_arm_public/          public Git repository: project-owned files only
minecraft-bedrock-server/    BDS_DIR: official BDS files supplied by each user
                             (external, not a Git repository, never committed)
```

The official Minecraft Bedrock Dedicated Server is **never** stored in the repository
directory. `.gitignore` is only a second layer of protection.

## Classification

| Component | Origin | Included in public repo? | Reason |
|---|---|---:|---|
| `scripts/*.sh` | This project | YES | Project source |
| `arm64.env` | This project | YES | Project configuration (Box64 settings, `BDS_DIR` default) |
| `systemd/bedrock.service`, `systemd/bedrock.socket` | This project | YES | Project unit templates |
| `README.md`, `docs/*.md`, `AUDIT.md` | This project | YES | Project documentation |
| `LICENSE` (MIT) | This project | YES | **REVIEW:** the author should confirm that MIT is the intended license |
| `.gitignore` | This project | YES | Safety net |
| Box64 source code | Third party (ptitSeb/box64, MIT) | NO | Not bundled. `install-deps.sh` downloads the v0.4.4 tarball from the official GitHub repository at install time |
| Box64 x86_64 `libgcc_s.so.1` | Third party (shipped by Box64; GCC runtime library) | NO | Installed by Box64's `make install` on the user's machine |
| Debian/Raspberry Pi OS packages | Third party | NO | Installed with `apt` by the user |
| `bedrock_server` binary | Microsoft/Mojang | NO | Proprietary |
| BDS assets: `behavior_packs/`, `resource_packs/`, `definitions/`, `config/default/`, `data/bootstrap.json`, `world_templates/`, `treatments/`, `premium_cache/`, `minecraftpe/`, `development_*_packs/` | Microsoft/Mojang | NO | Proprietary |
| BDS default configs: `server.properties`, `allowlist.json`, `permissions.json`, `packetlimitconfig.json`, `profanity_filter.wlist` | Microsoft/Mojang | NO | Proprietary files that also hold per-user settings |
| BDS documentation: `bedrock_server_how_to.html`, `release-notes.txt`, `Dedicated_Server.txt` | Microsoft/Mojang | NO | Proprietary |
| Official BDS zip archives | Microsoft/Mojang | NO | Proprietary |
| Minecraft worlds (LevelDB, `level.dat`) | User or runtime data | NO | Runtime and private data |
| Player data (allowlist, permissions, player records in worlds) | User | NO | Private data |
| Box64 DynaCache (`.box64-cache/`) | Runtime | NO | Generated data, stored in `BDS_DIR` |
| Server logs | Runtime | NO | Generated data |
| Backups | User | NO | Contain proprietary and private data |
| Secrets and credentials | User or private | NO | Security. None were found |

## Changes from the development copies

The project-owned files come from the private development folder (`bedrock_arm`). The
original x86_64 project (`bredrock_stable`) contained only official BDS files and user
data, so nothing was taken from it. Neither original folder was modified.

| File | Change |
|---|---|
| `arm64.env` | Added a configurable `BDS_DIR` (environment variable, or default `$HOME/minecraft-bedrock-server`). The DynaCache and `BOX64_LD_LIBRARY_PATH` now point to `BDS_DIR` |
| `scripts/start.sh` | Checks that `BDS_DIR` and `bedrock_server` exist, with clear errors. Runs the server from `BDS_DIR`. The ARM64 (Box64) and x86_64 (native) behavior is otherwise unchanged. The internal variable that used to point to the repository is now named `PROJECT_DIR` |
| `scripts/check-compat.sh` | Checks `BDS_DIR` (exists, writable, not inside the repository), the binary and `server.properties` inside `BDS_DIR`. Checks free disk space on `BDS_DIR` |
| `scripts/install-service.sh` | New `--bds-dir DIR` option. The default is `<user's home>/minecraft-bedrock-server`. The positional `user` argument is kept. Refuses `root` and paths that are inside the repository or contain unsafe characters. Warns if the directory isn't writable. Fills `@BDS_DIR@` in the units |
| `systemd/bedrock.service` | `Environment=BDS_DIR=@BDS_DIR@`, and `WorkingDirectory=@BDS_DIR@` |
| `scripts/install-deps.sh` | Only the final hint message changed |
| `scripts/console.sh`, `systemd/bedrock.socket` | Unchanged |

## Security review

The repository files were searched (case-insensitive) for:

- Passwords, API keys, tokens and secrets.
- Private key headers (`BEGIN ... PRIVATE KEY`).
- `.env` files and credential files.
- IP addresses and e-mail addresses.
- LevelDB and world files.

**Result:** no secrets, credentials, keys, private configuration or world data were
found. The only personal data is the author's public name ("Mohammad (DashWood)").
Example paths use `~` rather than a real home directory.
