# Architecture

## Why Box64?

`bedrock_server` is a **closed-source** binary. Mojang publishes it only for x86_64
Linux and Windows. There's no ARM build and no source code, so it can't be recompiled.

Native ARM64 Bedrock-protocol servers do exist, such as PocketMine-MP, Nukkit,
PowerNukkitX and Dragonfly. They are **different programs**, though, and they don't
behave like vanilla BDS with behavior packs and the `@minecraft/server` Script API.
This project keeps the real server and translates it instead.

| | |
|---|---|
| **Original architecture** | x86_64: an ELF 64-bit PIE, stripped, with interpreter `/lib64/ld-linux-x86-64.so.2` |
| **Target architecture** | AArch64 with a 64-bit glibc userland |
| **Mechanism** | Runtime binary translation with Box64. There is no recompilation, patching, full-system emulation, qemu or x86 root filesystem |
| **Modified official components** | None |
| **Added by this project** | Launcher, Box64 settings, installer, pre-flight check, systemd units |

## Layout at runtime

```text
~/bedrock_arm_public/  (repository)        ~/minecraft-bedrock-server/  (BDS_DIR)
  scripts/start.sh  ──── cd "$BDS_DIR" ───▶  bedrock_server   (x86_64, unmodified)
  arm64.env         ──── settings ────────▶  server.properties, worlds/, packs...
                                             .box64-cache/    (created at runtime)
/usr/local/bin/box64                         (built by install-deps.sh)
/usr/lib/box64-x86_64-linux-gnu/libgcc_s.so.1
```

`start.sh` sources `arm64.env`, checks `BDS_DIR` and `bedrock_server`, and changes
into `BDS_DIR`, because BDS reads its configuration and worlds from the working
directory. What happens next depends on the machine:

- **ARM64:** `exec box64 ./bedrock_server`
- **x86_64:** `exec env LD_LIBRARY_PATH=. ./bedrock_server`. This is Mojang's own
  command, and it runs natively, without Box64.

## How the translation works

- **Dynarec.** Box64 translates x86_64 code blocks into ARM64 code at runtime. With
  DynaCache enabled, the translations are saved to `$BDS_DIR/.box64-cache` and reused
  on the next start.
- **Library wrapping.** BDS links against `libc.so.6`, `libm.so.6`, `libdl.so.2`,
  `libpthread.so.0`, `librt.so.1` and `ld-linux-x86-64.so.2`. Box64 wraps all of these,
  so the calls go to the **native ARM64 glibc**. `libgcc_s.so.1` isn't wrapped;
  instead, Box64 ships an x86_64 copy that `make install` places in
  `/usr/lib/box64-x86_64-linux-gnu/`.
- **Instruction set.** Disassembling BDS 1.26.51.1 showed these extensions:
  - SSE / SSE4.2 (`crc32`)
  - BMI (`tzcnt`)
  - `rdtsc` and `cpuid` dispatch

  It uses **no AVX or AVX2**. The Box64 dynarec supports all of these extensions.
- **Bundled native files.** BDS 1.26.51.1 ships no `.so` files of its own.

## ARM64 considerations

- **Page size.** x86_64 programs expect 4 KB pages. The Pi 5's default 16 KB kernel is
  less compatible with Box64, so `kernel=kernel8.img` is recommended.
- **Memory ordering.** x86 guarantees stronger ordering than ARM. `STRONGMEM=0` is the
  fastest setting. Raise it if you see races under load.
- **Performance.** Translation costs CPU. Many players, redstone, farms and large view
  distances cost more than on a native x86 CPU of the same class.
- **Data portability.** LevelDB worlds (little-endian on both platforms), JSON and
  `.properties` files don't depend on the architecture, so existing worlds move
  unchanged.

## Differences from running BDS on x86_64

| Area | x86_64 (official) | ARM64 (this project) |
|---|---|---|
| Launch | `LD_LIBRARY_PATH=. ./bedrock_server` in the server directory | `scripts/start.sh` → `box64 ./bedrock_server` in `BDS_DIR` |
| First start | Fast | Slow while Box64 translates, then faster with the DynaCache |
| Extra runtime data | — | `$BDS_DIR/.box64-cache/` (up to 1 GB) |
| Suggested `view-distance` / `max-threads` | 32 / 8 | 12 / 4 |
| Gameplay, worlds, packs, Script API | Vanilla | Same binary, so vanilla |
