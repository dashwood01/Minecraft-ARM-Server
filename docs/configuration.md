# Configuration

## `BDS_DIR`

`BDS_DIR` is the directory that holds the **official Linux Bedrock Dedicated Server**
that you downloaded from minecraft.net. The files there are intentionally **not**
part of this repository:

- `bedrock_server`
- `server.properties`, `allowlist.json`, `permissions.json`
- `worlds/`, the packs, and so on

The scripts resolve `BDS_DIR` in this order:

| Order | Source | Used by |
|---|---|---|
| 1 | The `BDS_DIR` environment variable | `start.sh`, `check-compat.sh` |
| 2 | The default in `arm64.env`: `$HOME/minecraft-bedrock-server` | `start.sh`, `check-compat.sh` |
| — | `install-service.sh --bds-dir DIR`, or `<run user's home>/minecraft-bedrock-server` by default. It's written into the unit as `Environment=BDS_DIR=...` | systemd service |

**Rules:**

- A relative path is resolved against the current directory.
- `BDS_DIR` must contain `bedrock_server`. Otherwise `start.sh` stops with an error,
  and `check-compat.sh` reports FAIL.
- The server must be able to write to `BDS_DIR`, because it writes worlds and logs
  there, and the Box64 cache lives there too.
- `BDS_DIR` must be **outside** the repository. `check-compat.sh` warns if it isn't,
  and `install-service.sh` refuses to continue.
- For a permanent custom location, you can do either of the following:
  - Export `BDS_DIR` in your shell profile.
  - Change the default line in `arm64.env`.

## `arm64.env`

`start.sh` and `check-compat.sh` source this file, so the systemd service uses it too.

| Setting | Default | Purpose |
|---|---|---|
| `BDS_DIR` | `$HOME/minecraft-bedrock-server` | Official server directory (see above) |
| `BOX64_BIN` | `/usr/local/bin/box64` | Path to Box64. You can override it from the environment |
| `BOX64_NOBANNER`, `BOX64_LOG` | `1`, `0` | Keep Box64 output out of the console. Set `BOX64_LOG=1` or `2` for debugging |
| `BOX64_DYNACACHE` | `1` | Cache translated code on disk |
| `BOX64_DYNACACHE_FOLDER` | `$BDS_DIR/.box64-cache` | Cache location (runtime data, outside the repository) |
| `BOX64_DYNACACHE_LIMIT` | `1024` | Cache size limit in MB |
| `BOX64_DYNAREC_STRONGMEM` | `0` | x86 memory-ordering emulation. Use `1`, then `2`, if you see random crashes or hangs under load. Higher values cost a little CPU |
| `BOX64_LD_LIBRARY_PATH` | `$BDS_DIR` | Matches Mojang's `LD_LIBRARY_PATH=.` launch convention |

`start.sh` also reads `BDS_FORCE_BOX64=1`, which forces the Box64 path on an x86_64
machine. It's only useful for testing under `qemu-aarch64` (see
[development.md](development.md)).

## `scripts/install-deps.sh` options

| Option | Purpose |
|---|---|
| `--fix-pagesize` | Switch to the 4 KB-page kernel (Pi 5). A reboot is required |
| `--jobs N` | Set the number of parallel compile jobs |

To try another Box64 release, change `BOX64_VERSION` at the top of the script.

## `scripts/install-service.sh` options

| Option | Purpose |
|---|---|
| `--bds-dir DIR` | Official server directory |
| `user` (positional) | Account that runs the server. The default is the owner of `--bds-dir`, or the owner of the repository if `--bds-dir` isn't given. `root` is refused |

## Official BDS settings (in `BDS_DIR`)

These files belong to Mojang's server, and Mojang documents them in `server.properties`
itself and in `bedrock_server_how_to.html`. This project doesn't edit them.

**Values worth reviewing on a Pi** (the defaults are from `server.properties` in BDS
1.26.51.1):

| Key | Default | Suggested on a Pi | Why |
|---|---|---|---|
| `view-distance` | `32` | `12` (or `8`–`10` on 2–4 GB boards) | Heavy RAM and CPU load |
| `max-threads` | `8` | `4` | The Pi 4 and Pi 5 have 4 cores |
| `tick-distance` | `4` | `4` | Already the minimum |
| `server-port` / `server-portv6` | `19132` / `19133` | — | Change them if the ports are taken |
| `transport` | `nethernet` | `nethernet` | BDS 1.26.51 reports that NetherNet is the only supported transport |
| `online-mode` | `true` | `true` for public servers | Requires Xbox Live authentication |
| `allow-list` | `true` | — | Only players listed in `allowlist.json` can join |

**Other official files:**

- `allowlist.json`: allowed players.
- `permissions.json`: per-player permission levels.
- `packetlimitconfig.json`: network packet limits.
- `profanity_filter.wlist`: the chat filter.
