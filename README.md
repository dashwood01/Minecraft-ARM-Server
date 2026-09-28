# Bedrock ARM — Minecraft Bedrock Dedicated Server on Raspberry Pi (ARM64)

> Hi, I'm **Mohammad Nazem**, a software developer interested in Android,
> Flutter, Linux and self-hosted systems. I initiated and directed this project,
> with development and porting assistance from Claude Code.

**Bedrock ARM** is a set of launcher, installer and service scripts. It runs the
**official, unmodified x86_64 Minecraft Bedrock Dedicated Server (BDS)** on **64-bit
ARM Linux (aarch64)**, and it targets **Raspberry Pi OS Lite (64-bit)**.

It is **not** an ARM build of the server, and it doesn't patch or recompile anything.
Mojang publishes BDS only for x86_64 Linux and Windows, as a closed-source binary. This
project builds **[Box64](https://github.com/ptitSeb/box64)**, an open-source x86_64 →
ARM64 binary translator, on your Pi. It then runs the official server through Box64,
adding tuned settings, a pre-flight check and an optional systemd service.

> [!IMPORTANT]
> **Disclaimer**
>
> - This is an **unofficial, independent** project. It is **not affiliated with,
>   endorsed by or supported by Microsoft or Mojang Studios**.
> - This repository contains **no Microsoft or Mojang files**.
> - Download the official Bedrock Dedicated Server yourself from
>   [minecraft.net](https://www.minecraft.net/en-us/download/server/bedrock). By doing
>   so, you accept Mojang's EULA and Privacy Policy.
> - This project grants **no rights** to Microsoft or Mojang software. "Minecraft" is
>   a trademark of Microsoft.

---

## Contents

- [How it works](#how-it-works)
- [Requirements](#requirements)
- [Installation](#installation)
- [Configuration](#configuration)
- [Running the server](#running-the-server)
- [Connecting](#connecting)
- [Troubleshooting](#troubleshooting)
- [Limitations and project status](#limitations-and-project-status)
- [Directory structure](#directory-structure)
- [License](#license)
- [Contributing](#contributing)
- [Development note](#development-note)
- [Official resources](#official-resources)

## How it works

The project uses **two separate directories**:

```text
~/bedrock_arm_public/          ← this Git repository (project files only)
~/minecraft-bedrock-server/    ← official BDS files you download yourself (BDS_DIR)
                                  NOT part of this repository, NOT a Git repository
```

1. `scripts/install-deps.sh` downloads the Box64 **v0.4.4** source, builds it on the Pi
   with the right profile for your board, and installs it.
2. You download the official **Linux** BDS zip and extract it into `BDS_DIR`, which
   defaults to `~/minecraft-bedrock-server`.
3. `scripts/check-compat.sh` checks the machine and `BDS_DIR`.
4. `scripts/start.sh` changes into `BDS_DIR` and runs `box64 ./bedrock_server`. On
   x86_64 it runs the server natively instead, as Mojang documents.

The server binary, worlds and settings are used **as they are**. The project adds only
the launcher, the Box64 settings (`arm64.env`) and the systemd units. For details, see
[docs/architecture.md](docs/architecture.md).

| This repository **contains** | This repository **does not contain** |
|---|---|
| ARM launcher and helper scripts (`scripts/`) | The Minecraft Bedrock Dedicated Server |
| Box64 build and integration (the installer downloads the Box64 source from its official GitHub repository; none is bundled) | `bedrock_server` or any Microsoft/Mojang binaries or libraries |
| Runtime configuration (`arm64.env`) | Minecraft assets: behavior and resource packs, definitions |
| systemd unit templates (`systemd/`) | Worlds, LevelDB data or player data |
| Documentation (`README.md`, `docs/`, `AUDIT.md`), `LICENSE` | Server runtime data, logs, the Box64 cache, backups or official BDS archives |

## Requirements

| Item | Requirement |
|---|---|
| CPU / OS | 64-bit ARM kernel (`uname -m` = `aarch64`) **and** 64-bit userland (`dpkg --print-architecture` = `arm64`). The scripts check for both, and a 32-bit OS won't work |
| Target OS | Raspberry Pi OS Lite (64-bit), Debian 12 "bookworm" or 13 "trixie" based. The scripts use `apt`, `dpkg` and systemd |
| Board | Raspberry Pi 5 / 500 / CM5 or Pi 4 / 400 / CM4 recommended (the installer has Box64 profiles for them). The Pi 3 / Zero 2 W have a profile, but their 1 GB of RAM is below the check's minimum |
| RAM | 4 GB or more recommended, and 2 GB works for a few players. `check-compat.sh` fails below about 1.8 GB and warns below 1 GB of swap |
| Page size | 4 KB recommended. The Pi 5 defaults to 16 KB, and the installer can switch it (see [installation](docs/installation.md)) |
| Disk | About 1 GB for the Box64 build, the server and the cache, plus your worlds. The check warns below 2 GB free |
| Setup | `sudo`, plus internet access to apt mirrors and GitHub to fetch the Box64 source |
| Official server | The **Linux** build of BDS. The **project-tested** pair is BDS **1.26.51.1** with Box64 **v0.4.4**. Other versions haven't been tested |
| Network | UDP **19132** (IPv4) and **19133** (IPv6), the BDS defaults |

## Installation

This is the short version. [docs/installation.md](docs/installation.md) explains each
step in detail.

```bash
# 1. On a fresh Raspberry Pi OS Lite (64-bit)
sudo apt update && sudo apt full-upgrade -y && sudo reboot
uname -m; dpkg --print-architecture          # must print aarch64 / arm64

# 2. Get this project
sudo apt install -y git
git clone <repository-url> ~/bedrock_arm_public
cd ~/bedrock_arm_public

# 3. Build and install Box64 (5–25 min)
sudo ./scripts/install-deps.sh               # Pi 5 on the 16K kernel: add --fix-pagesize, then reboot
```

Replace `<repository-url>` with this repository's GitHub URL.

**4. Get the official server.** Download the **Ubuntu (Linux)** zip from
<https://www.minecraft.net/en-us/download/server/bedrock> and copy it to the Pi. Then
extract it into a **separate** directory, never into this repository:

```bash
mkdir -p ~/minecraft-bedrock-server
unzip ~/bedrock-server-*.zip -d ~/minecraft-bedrock-server
```

**5. Check the setup:**

```bash
./scripts/check-compat.sh                    # ends with "Result: ready."
```

## Configuration

### `BDS_DIR`: where the official server lives

`BDS_DIR` is the directory that contains the official `bedrock_server` and its files
(`server.properties`, `worlds/`, and so on). It's resolved in this order:

1. The `BDS_DIR` environment variable, if it's set.
2. Otherwise, the default in `arm64.env`: `$HOME/minecraft-bedrock-server`.
3. For the systemd service, `install-service.sh` writes the directory into the unit
   file (`--bds-dir DIR`).

```bash
BDS_DIR="$HOME/minecraft-bedrock-server" ./scripts/start.sh
```

The scripts stop with a clear error if `BDS_DIR` or `bedrock_server` is missing. They
never download or copy Minecraft files.

### Other settings

- **`arm64.env`** holds the Box64 runtime settings: logging, the DynaCache in
  `$BDS_DIR/.box64-cache` and memory-ordering options.
- **Server settings** are Mojang's own files in `BDS_DIR`. On a Pi, lowering
  `view-distance` (Mojang's default is 32; 12 is suggested) and `max-threads`
  (default 8; the Pi has 4 cores) is recommended.

Every setting is explained in [docs/configuration.md](docs/configuration.md).

## Running the server

**Foreground** (type console commands directly, and `stop` to save and quit):

```bash
~/bedrock_arm_public/scripts/start.sh
```

The first start is slow, because Box64 translates the 256 MB binary. Later starts reuse
the cache. The server is ready when it prints `Server started.`

**As a systemd service** (headless, starts at boot):

```bash
sudo ./scripts/install-service.sh --bds-dir ~/minecraft-bedrock-server
sudo systemctl start bedrock
```

| Task | Command |
|---|---|
| Live log and console output | `journalctl -u bedrock -f` |
| Send a console command | `./scripts/console.sh list` |
| Status | `systemctl status bedrock` |
| Stop cleanly (sends `stop`, waits for the save) | `sudo systemctl stop bedrock` |
| Restart | `sudo systemctl restart bedrock` |

For the unit details, how the FIFO console works and how to uninstall, see
[docs/systemd.md](docs/systemd.md).

## Connecting

This is standard BDS behavior; the project adds nothing here.

- Players connect to the Pi's IP address (`hostname -I`) on UDP port **19132**.
- With `enable-lan-visibility=true` (the default), the server also appears as a LAN
  game on the same network.
- For internet play, forward UDP 19132 (and 19133 for IPv6) on your router, and keep
  `online-mode=true` and the allowlist on.
- Client and server versions must match.
- Mojang's `bedrock_server_how_to.html`, which comes with BDS, documents every server
  setting and command.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `ERROR: BDS_DIR '...' does not exist` or `bedrock_server not found in BDS_DIR` | Extract the official Linux BDS there, or set `BDS_DIR` |
| `ERROR: Box64 not found at /usr/local/bin/box64` | Run `sudo ./scripts/install-deps.sh` |
| `kernel is armv7l` / `userland is armhf` | Reinstall with the **64-bit** Raspberry Pi OS |
| Crash right at start on a Pi 5 | Run `getconf PAGESIZE`. If it prints `16384`, use the 4 KB kernel |
| "Your current connection type is not set to NetherNet" | Set `transport=nethernet` in `server.properties` |
| Out of memory | Lower `view-distance`, add swap, or use a board with more RAM |

For the full list and how to collect diagnostics, see
[docs/troubleshooting.md](docs/troubleshooting.md).

## Limitations and project status

**Status: experimental.**

- **Not yet tested on real Raspberry Pi hardware.** The ARM64 code path was verified
  under `qemu-aarch64` user-mode emulation on an x86_64 PC:
  - Box64 v0.4.4 was built for AArch64.
  - BDS 1.26.51.1 started, loaded a world, answered a ping, ran console commands and
    stopped cleanly.

  See [docs/development.md](docs/development.md).
- Real performance and player capacity on a Pi haven't been measured. Translation adds
  overhead, so expect a small group of players at a reduced view distance.
- 16 KB-page kernels (the Pi 5 default) are less compatible with Box64.
- Neither Mojang nor Box64 guarantees that future BDS releases will work under Box64.
- The server can't be made truly native, because it's closed source.

## Directory structure

```text
bedrock_arm_public/            ← this repository
├── README.md
├── LICENSE                    covers this project's own files only
├── AUDIT.md                   what is and isn't included, and why
├── .gitignore                 extra safety net against committing server or world data
├── arm64.env                  BDS_DIR default + Box64 runtime settings
├── scripts/
│   ├── install-deps.sh        apt packages + native Box64 build/install (sudo)
│   ├── check-compat.sh        pre-flight check of the machine and BDS_DIR
│   ├── start.sh               launcher (Box64 on ARM64, native on x86_64)
│   ├── install-service.sh     installs the systemd units (sudo)
│   └── console.sh             sends a command to the running service
├── systemd/
│   ├── bedrock.service        unit template (@USER@, @DIR@, @BDS_DIR@)
│   └── bedrock.socket         FIFO console for the service's stdin
└── docs/                      detailed documentation

minecraft-bedrock-server/      ← EXTERNAL (BDS_DIR): official files you download
├── bedrock_server                not part of this repository
├── server.properties
├── allowlist.json
├── permissions.json
├── worlds/
├── .box64-cache/                 created by start.sh
└── ...
```

## License

This project's own files (the scripts, `arm64.env`, the systemd units and the
documentation) are released under the [MIT License](LICENSE).

The license **does not** cover Minecraft, the Bedrock Dedicated Server or any other
Microsoft or Mojang software. That software is proprietary, isn't included here, and is
governed by Mojang's EULA. Box64 is a separate project under its own MIT license. It's
downloaded from its official repository during installation, and none of it is
included here.

## Contributing

Test reports from real Raspberry Pi boards are especially welcome. To contribute:

1. Fork the repository and create a branch.
2. Run `bash -n scripts/*.sh`.
3. Test on an ARM64 device.
4. Open a pull request that names your hardware and OS.

**Never commit Minecraft files, worlds or runtime data.** See
[docs/development.md](docs/development.md).

## Development note

I initiated and directed this project. The ARM porting and development work was done
with assistance from **Claude Code**, Anthropic's AI coding assistant. The project is
mine; Claude Code was a tool I used.

## Official resources

- Bedrock Dedicated Server download: <https://www.minecraft.net/en-us/download/server/bedrock>
- Minecraft EULA: <https://www.minecraft.net/en-us/eula>
- BDS bug tracker (Mojang): <https://bugs.mojang.com/projects/BDS/issues>
- Minecraft changelogs: <https://aka.ms/MinecraftUpdate>
- Box64 (third-party translator): <https://github.com/ptitSeb/box64>
