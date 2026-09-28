# Development

## Workflow

```bash
git clone <repository-url> bedrock_arm_public
cd bedrock_arm_public
git checkout -b my-change
# edit scripts/, systemd/, arm64.env or docs/
bash -n scripts/*.sh arm64.env
```

Open a pull request that describes the change and the hardware and OS you tested on.

**Never commit Minecraft files.** This includes `bedrock_server`, packs, definitions,
`server.properties`, worlds, logs, `.box64-cache/`, backups and BDS zips. Keep your
test server in a directory outside the repository. `.gitignore` is only a safety net.

## Testing without the official server

You can test the path handling and the Box64 path on any machine by using stub
programs:

```bash
T=$(mktemp -d); mkdir -p "$T/bds" "$T/bin"
printf '#!/bin/sh\necho "server cwd=$(pwd) LD=$LD_LIBRARY_PATH"\n' > "$T/bds/bedrock_server"
printf '#!/bin/sh\necho "box64 $* cache=$BOX64_DYNACACHE_FOLDER"\n' > "$T/bin/box64"
chmod +x "$T/bds/bedrock_server" "$T/bin/box64"

BDS_DIR="$T/nope" ./scripts/start.sh                     # clear error, exit 1
BDS_DIR="$T/bds"  ./scripts/start.sh                     # x86_64: native path
BDS_DIR="$T/bds" BDS_FORCE_BOX64=1 BOX64_BIN="$T/bin/box64" ./scripts/start.sh
BDS_DIR="$T/bds" ./scripts/check-compat.sh               # FAILs expected on x86_64
```

To check the systemd templates, render them the same way the installer does, then run
`systemd-analyze verify`:

```bash
for u in bedrock.socket bedrock.service; do
  sed -e "s|@USER@|$USER|g" -e "s|@DIR@|$PWD|g" -e "s|@BDS_DIR@|$T/bds|g" systemd/$u > "$T/$u"
done
systemd-analyze verify "$T/bedrock.socket" "$T/bedrock.service"
```

## Verification performed so far

No Raspberry Pi was available during development. Verification took place on an
x86_64 machine running Ubuntu, with an emulated ARM64 userland.

1. **Box64 v0.4.4 was cross-compiled for AArch64** with the upstream `-DRPI4ARM64=1`
   profile.
   - The compiler was `zig cc` targeting `aarch64-linux-gnu` with glibc 2.36, the
     bookworm baseline.
   - The build finished with 0 errors and produced an `ELF 64-bit LSB executable, ARM
     aarch64`.
2. **Runtime test** of `qemu-aarch64` (user mode, 10.0) → Box64 (ARM64) →
   `bedrock_server` 1.26.51.1 (x86_64), with Debian 13 arm64 `libc6` and `libgcc-s1`.
   BDS:
   - Printed `Version: 1.26.51.1`.
   - Created a world and printed `Server started.`
   - Bound its UDP ports.
   - Answered a RakNet unconnected ping with a valid pong.
   - Ran `list`.
   - Stopped with `Quit correctly` (exit code 0).
3. **An existing world** loaded through `scripts/start.sh` with `arm64.env`, then saved
   and stopped cleanly.
4. **Static checks:**
   - `bash -n` passed on all scripts.
   - `systemd-analyze verify` passed on the rendered units.
5. **After the move to an external `BDS_DIR`,** `start.sh`, `check-compat.sh` and
   the unit templates were tested again with stub binaries, as described above. The
   `check-compat.sh` binary check was also run against a real BDS 1.26.51.1 binary.

The qemu figures (about 2.5–3 minutes to start, about 1.7 GB RSS) include qemu's
overhead. They say nothing about real Pi performance.

**Wanted:** results from real Raspberry Pi 4 and Pi 5 boards. Please include:

- The `check-compat.sh` output.
- The time to `Server started.` on the first and second starts.
- Memory use.
- The number of players.
