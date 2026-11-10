# Cortex-M in the Browser with QEMU — Brief Plan

## 1. What exists today (research)
- **ktock/qemu-wasm**: real QEMU compiled to WebAssembly with Emscripten. It started with the TCI interpreter. A Wasm TCG backend (hot code compiled to Wasm) is in patch v4 on qemu-devel and was **not merged upstream** when I checked. This is most likely the project your friend used to boot full Linux in the browser.
- **JSLinux / v86**: run Linux in the browser too, but they are not QEMU and don't emulate Cortex-M.
- **QEMU Cortex-M support** (`qemu-system-arm`): core CPU (M0/M3/M4F/M7/M33/M55), NVIC, SysTick, MPU, FPU, TrustZone-M.

**Idea:** build only `arm-softmmu` with Emscripten (based on qemu-wasm), boot `firmware.elf` with `-kernel`, and connect UART/GPIO to a web UI. Cortex-M firmware is tiny, so the slower TCI interpreter is fast enough for firmware development.

## 2. Boards QEMU already has
| Board (`-M`) | MCU / core | Useful peripherals |
|---|---|---|
| `mps2-an385` / `an386` / `an500` | Arm MPS2, M3 / M4 / M7 | CMSDK UART, timers, dual-timer, watchdog, GPIO, LAN9118 Ethernet |
| `mps2-an505` / `an521`, `mps3-an547` | M33 / M55 (TrustZone) | Same as above, plus TrustZone security controllers |
| `lm3s6965evb`, `lm3s811evb` | TI Stellaris, M3 | UART, GPTM timers, GPIO, I2C, SSI, ADC, Ethernet |
| `stm32vldiscovery` | STM32F100, M3 | USART (most other blocks are stubs) |
| `netduino2`, `netduinoplus2`, `olimex-stm32-h405` | STM32F2/F4, M3/M4 | USART, TIM2–5, SPI, ADC, EXTI, SYSCFG |
| `b-l475e-iot01a` | STM32L475, M4F | RCC, GPIO, EXTI, SYSCFG, USART |
| `microbit` | nRF51, M0 | UART, GPIO, timers, RNG |

**Recommended first targets:** `mps2-an386` (Cortex-M4, clean CMSIS, best UART/timer support), then `b-l475e-iot01a` for STM32 HAL users.

## 3. What can be emulated in the browser ✅
- CPU core, interrupts (NVIC), SysTick, MPU, FPU, TrustZone-M (M33)
- UART → shown in a browser terminal (xterm.js)
- Timers, watchdog, EXTI and GPIO on the boards listed above → shown as virtual LEDs and buttons in the page
- Semihosting `printf`
- SPI, I2C and ADC on some boards (with fake or stub data)
- Loading `.elf`/`.bin` from the browser (file upload → Emscripten FS → `-kernel`), plus reset, pause and step

## 4. What cannot, or only partly ❌
- **Cycle-accurate timing** and real clock trees: RCC is mostly stubbed, except on L4.
- **DMA, USB, CAN, I2S, SDIO, flash programming/option bytes, low-power modes**: mostly not implemented.
- **Unimplemented registers read as 0**, so STM32 HAL code can hang (e.g. waiting forever for `HSE ready`). We will need small stub or custom models.
- **Analog and external sensors, BLE, Wi-Fi radio**: not modeled. We would have to write them ourselves.
- **Browser limits**: no raw TCP, so Ethernet and GDB need a WebSocket bridge. Multi-threading needs `SharedArrayBuffer`, which requires COOP/COEP headers. Wasm memory is capped.
- **Real debug probe (SWD/JTAG)**: not possible.

## 5. Phased plan
1. **Build**: compile `qemu-system-arm` (`--target-list=arm-softmmu`) with Emscripten, using the qemu-wasm approach. Run a UART hello-world on `mps2-an386` in Node, then in the browser.
2. **Web UI**: firmware upload, run/reset, serial terminal.
3. **Peripheral view**: a JS bridge for GPIO (LEDs and buttons) and register/peripheral state.
4. **Dev workflow**: compile firmware locally (`arm-none-eabi-gcc`) and drag it into the page. Later: GDB over a WebSocket bridge.
5. **Extend**: add missing STM32 peripheral stubs/models as real firmware needs them.

*Alternatives if QEMU's peripheral gaps block us:* Renode (many more peripherals, but .NET, so hard to run in a browser) or a custom JS/Wasm Cortex-M core (the Wokwi-style approach).
