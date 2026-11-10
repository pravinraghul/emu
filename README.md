# emu: Cortex-M firmware in the browser (QEMU-Wasm)

Runs bare-metal Cortex-M firmware inside the browser with QEMU compiled to WebAssembly.
The first milestone is a **Hello World over UART** on a board-independent machine.

```
firmware/hello.elf ──▶ QEMU (qemu-system-arm.wasm, machine "generic-cortex-m") ──▶ UART0 ──▶ xterm.js
```

See [PLAN.md](PLAN.md) for the research notes and what can and cannot be emulated.

## The `generic-cortex-m` machine

A minimal QEMU machine that is not tied to any real board ([qemu/generic-cortex-m.patch](qemu/generic-cortex-m.patch)):

| Address      | What                                              |
|--------------|---------------------------------------------------|
| `0x00000000` | Flash, 256 KiB (`-M generic-cortex-m,flash-size=512K`), vector table |
| `0x20000000` | SRAM, 64 KiB (`-m 128K`)                          |
| `0x40004000` | UART0: Arm CMSDK APB UART, NVIC IRQ 0, wired to the first serial port |

- The NVIC, SysTick and, where the core has them, the MPU and FPU are built into the core.
- The CPU defaults to `cortex-m3`. Pick another with `-cpu cortex-m0|m3|m4|m7|m33`.
- Clocks: 25 MHz core/UART clock, 1 MHz SysTick reference.

The board is chosen when QEMU starts (`-M`), so a single `.wasm` build serves every firmware and core.

## Layout

```
firmware/   Hello World: startup.c (vectors/reset), main.c (UART), link.ld, Makefile
qemu/       generic-cortex-m.patch (against ktock/qemu-wasm @ 0ef7b4e, QEMU 8.2)
scripts/    build-wasm-deps.sh   zlib, libffi, pcre2, glib for Emscripten
            build-qemu-wasm.sh   qemu-system-arm.{js,wasm,worker.js} into web/
            serve.py             dev server with the COOP/COEP headers
            browser-test.mjs     headless-Chromium check for "Hello World"
web/        index.html, vendor/ (xterm.js, xterm-pty), emulator and firmware
```

## Build and run

Prerequisites (Debian/Ubuntu): `gcc-arm-none-eabi`, `autoconf`, `libtool`, `libltdl-dev`, `pkg-config`, `ninja-build`, `meson==1.5.0` (pip), Node.js, and [emsdk](https://github.com/emscripten-core/emsdk) 3.1.50 at `../build/emsdk`.
The scripts use `../build/` (next to this repo) as their work directory. Override it with `BUILD_ROOT=...`.

```sh
# 1. firmware
make -C firmware && cp firmware/hello.elf web/

# 2. emulator (one-time, ~20-40 min): Wasm libraries, then QEMU
scripts/build-wasm-deps.sh
scripts/build-qemu-wasm.sh

# 3. serve and open http://127.0.0.1:8088/
scripts/serve.py
#    options: ?cpu=cortex-m4  ?fw=other.elf

# 4. automated check (headless Chromium + screenshot)
node scripts/browser-test.mjs http://127.0.0.1:8088/ hello-world.png
```

The page must be served with `Cross-Origin-Opener-Policy: same-origin` and `Cross-Origin-Embedder-Policy: require-corp`. QEMU's threads need `SharedArrayBuffer`, which requires them. `serve.py` sets both.

### Native QEMU (no browser), for quick checks

```sh
mkdir ../build/qemu-native && cd ../build/qemu-native
../qemu-wasm/configure --target-list=arm-softmmu --without-default-features \
  --without-default-devices --with-devices-arm=cortex-m --enable-system \
  --with-coroutine=ucontext --disable-werror
ninja qemu-system-arm
./qemu-system-arm -M generic-cortex-m -nographic -kernel ../../emu/firmware/hello.elf
```

## License note

QEMU is GPL-2.0. The patch in `qemu/` is GPL-2.0-or-later. If you serve the `.wasm` to users, publish the QEMU source and patch alongside it.
