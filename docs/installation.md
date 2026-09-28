# Installation

This guide describes a complete installation on a Raspberry Pi. It assumes the
repository is cloned to `~/bedrock_arm_public` and the official server goes in
`~/minecraft-bedrock-server`. You can use other paths, as long as the server directory
is **outside** the repository.

## 1. Prepare the operating system

Flash **Raspberry Pi OS Lite (64-bit)** with Raspberry Pi Imager. Enable SSH in the
Imager settings if you want to work remotely. After the first boot, run:

```bash
sudo apt update && sudo apt full-upgrade -y
sudo reboot
```

Then check the system:

```bash
uname -m                     # must print: aarch64
dpkg --print-architecture    # must print: arm64
getconf PAGESIZE             # 4096 is ideal; 16384 = 16K kernel (Pi 5 default)
```

## 2. Get the project

```bash
sudo apt install -y git
git clone <repository-url> ~/bedrock_arm_public
cd ~/bedrock_arm_public
```

## 3. Install dependencies and build Box64

```bash
sudo ./scripts/install-deps.sh
```

On a **Raspberry Pi 5 with the 16 KB kernel**, run this instead, and reboot afterwards:

```bash
sudo ./scripts/install-deps.sh --fix-pagesize
sudo reboot
```

`--fix-pagesize` backs up `/boot/firmware/config.txt` (or `/boot/config.txt`) and
appends `kernel=kernel8.img`. Box64 has some support for 16 KB pages, but x86_64
programs expect 4 KB pages, which give the best compatibility. To make the same change
by hand:

```bash
echo -e '\n[all]\nkernel=kernel8.img' | sudo tee -a /boot/firmware/config.txt
sudo reboot
```

### What `install-deps.sh` does

1. It checks for root, an `aarch64` kernel and an `arm64` userland, and stops with an
   error if any is missing.
2. It reads `/proc/device-tree/model` and picks a Box64 profile:

   | Board | Profile |
   |---|---|
   | Pi 5, Pi 500, CM5 | `-DRPI5ARM64=1` |
   | Pi 4, Pi 400, CM4 | `-DRPI4ARM64=1` |
   | Pi 3, Zero 2 | `-DRPI3ARM64=1` |
   | Any other board | Generic `-DARM_DYNAREC=ON`, with a warning |

3. It installs `build-essential cmake python3 curl ca-certificates unzip` with
   `--no-install-recommends`. These are build tools only, with no GUI packages. The
   server needs no extra runtime packages.
4. It downloads the Box64 **v0.4.4** source tarball from GitHub into
   `/usr/local/src/box64-0.4.4` and builds it with `RelWithDebInfo`.
   - It uses 1 job below 1.5 GB of RAM, 2 jobs below 3 GB, and one job per CPU core
     otherwise.
   - You can override this with `--jobs N`.
5. It runs `make install`. This installs `/usr/local/bin/box64` and an **x86_64
   `libgcc_s.so.1`** in `/usr/lib/box64-x86_64-linux-gnu/`, which `bedrock_server`
   needs. It then restarts `systemd-binfmt`.
6. It checks that `box64 --version` works and that `libgcc_s.so.1` is present.

The build takes about 5–10 minutes on a Pi 5 and 15–25 minutes on a Pi 4.

<details>
<summary>Equivalent manual commands</summary>

```bash
sudo apt install -y --no-install-recommends build-essential cmake python3 curl ca-certificates unzip
cd /usr/local/src
sudo curl -fsSL https://github.com/ptitSeb/box64/archive/refs/tags/v0.4.4.tar.gz | sudo tar -xz
cd box64-0.4.4 && sudo mkdir build && cd build
sudo cmake .. -DRPI5ARM64=1 -DCMAKE_BUILD_TYPE=RelWithDebInfo   # Pi 4: -DRPI4ARM64=1
sudo make -j4
sudo make install
sudo systemctl restart systemd-binfmt
```
</details>

## 4. Get the official Bedrock Dedicated Server

This project doesn't include or download Minecraft files. You get them yourself:

1. On any computer, open
   <https://www.minecraft.net/en-us/download/server/bedrock>, accept the EULA and
   Privacy Policy, and download the **Ubuntu (Linux)** build. It's a file named like
   `bedrock-server-<version>.zip`. The Windows build won't work.
2. Copy the zip to the Pi, for example with
   `scp bedrock-server-*.zip <user>@<pi-address>:~/`.
3. Extract it into a directory **outside** the repository:

   ```bash
   mkdir -p ~/minecraft-bedrock-server
   unzip ~/bedrock-server-*.zip -d ~/minecraft-bedrock-server
   ```

If you already have a BDS directory with your own worlds, copy that whole directory
instead, for example with `cp -a` or `rsync -a`. Worlds need no conversion for ARM.

If you use a path other than `~/minecraft-bedrock-server`, set `BDS_DIR` (see
[configuration.md](configuration.md)).

## 5. (Recommended) Tune the server for a Raspberry Pi

This step is optional and changes Mojang's own settings file:

```bash
sed -i -e 's/^view-distance=.*/view-distance=12/' \
       -e 's/^max-threads=.*/max-threads=4/' ~/minecraft-bedrock-server/server.properties
```

## 6. Verify

```bash
cd ~/bedrock_arm_public
./scripts/check-compat.sh
```

It checks:

- The architecture and userland.
- The page size.
- Box64 and the x86_64 `libgcc_s`.
- That `BDS_DIR` exists, is writable, and isn't inside the repository.
- That `bedrock_server` is present and is an x86_64 binary.
- RAM and swap.
- That the UDP ports from `server.properties` are free.
- Free disk space.

On a ready system, the output ends with `Result: ready.` `[WARN]` lines don't block
starting.

Next, see [Running the server](../README.md#running-the-server) or
[systemd.md](systemd.md).

## Updating

### This project

```bash
cd ~/bedrock_arm_public && git pull
```

If `BOX64_VERSION` in `scripts/install-deps.sh` changed, run `install-deps.sh` again.
If the files in `systemd/` changed, run `install-service.sh` again.

### The official server

Bedrock clients update automatically, and a client can only join a server of the same
version. To update the server:

1. Download the new Linux build from minecraft.net.
2. Stop the server, then back up the server directory:

   ```bash
   sudo systemctl stop bedrock        # or type "stop" in the console
   tar czf ~/bedrock-backup-$(date +%F).tgz -C ~ minecraft-bedrock-server
   ```

3. Extract the new build over it without overwriting your settings and worlds:

   ```bash
   cd ~/minecraft-bedrock-server
   unzip -o ~/bedrock-server-*.zip -x 'server.properties' 'allowlist.json' 'permissions.json' 'worlds/*'
   ```

4. Run `./scripts/check-compat.sh` and start the server. The first start is slow again,
   because the DynaCache is rebuilt for the new binary.

If a new BDS release crashes under Box64, try a newer Box64 (change `BOX64_VERSION`)
or go back to the previous BDS version from your backup.
