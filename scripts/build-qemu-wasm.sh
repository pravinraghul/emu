#!/usr/bin/env bash
# Build qemu-system-arm for the browser (Emscripten / WebAssembly) with only the
# "generic-cortex-m" machine. Needs scripts/build-wasm-deps.sh to have run first.
#
# Output: web/qemu-system-arm.{js,wasm,worker.js}
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_ROOT="${BUILD_ROOT:-$(cd "$REPO/.." && pwd)/build}"
EMSDK="${EMSDK:-$BUILD_ROOT/emsdk}"
QEMU_SRC="$BUILD_ROOT/qemu-wasm"
QEMU_REV=0ef7b4e2814b231705d8371dd7997f5b72e70baf     # ktock/qemu-wasm (QEMU 8.2 + Wasm TCG)
OUT="$BUILD_ROOT/qemu-wasm-build"
TARGET="$BUILD_ROOT/wasm-target"
NPM="$BUILD_ROOT/npm"

# shellcheck disable=SC1091
source "$EMSDK/emsdk_env.sh" >/dev/null

# 1. QEMU source + our machine patch
if [ ! -d "$QEMU_SRC/.git" ]; then
  git clone -q https://github.com/ktock/qemu-wasm "$QEMU_SRC"
  git -C "$QEMU_SRC" checkout -q "$QEMU_REV"
fi
if git -C "$QEMU_SRC" apply --check "$REPO/qemu/generic-cortex-m.patch" 2>/dev/null; then
  git -C "$QEMU_SRC" apply "$REPO/qemu/generic-cortex-m.patch"
elif ! git -C "$QEMU_SRC" apply --check --reverse "$REPO/qemu/generic-cortex-m.patch" 2>/dev/null; then
  echo "generic-cortex-m.patch neither applies nor is already applied" >&2; exit 1
fi

# 2. xterm-pty: Emscripten TTY <-> xterm.js bridge
[ -f "$NPM/node_modules/xterm-pty/emscripten-pty.js" ] ||
  (mkdir -p "$NPM" && cd "$NPM" && npm i -s xterm-pty@0.10.1)

# 3. configure + build
export PKG_CONFIG_PATH="$TARGET/lib/pkgconfig" EM_PKG_CONFIG_PATH="$TARGET/lib/pkgconfig"
export CPATH="$TARGET/include" LDFLAGS="-L$TARGET/lib"
EXTRA_CFLAGS="-O3 -g -Wno-error=unused-command-line-argument -matomics -mbulk-memory -DNDEBUG \
-DG_DISABLE_ASSERT -D_GNU_SOURCE -sASYNCIFY=1 -pthread -sPROXY_TO_PTHREAD=1 -sFORCE_FILESYSTEM \
-sALLOW_TABLE_GROWTH -sTOTAL_MEMORY=512MB -sWASM_BIGINT -sMALLOC=mimalloc \
--js-library=$NPM/node_modules/xterm-pty/emscripten-pty.js -sEXPORT_ES6=1 -sASYNCIFY_IMPORTS=ffi_call_js"

mkdir -p "$OUT" && cd "$OUT"
if [ ! -f build.ninja ]; then
  emconfigure "$QEMU_SRC/configure" --static --target-list=arm-softmmu --cpu=wasm32 --cross-prefix= \
    --without-default-features --without-default-devices --with-devices-arm=cortex-m \
    --enable-system --with-coroutine=fiber --disable-werror \
    --extra-cflags="$EXTRA_CFLAGS" --extra-cxxflags="$EXTRA_CFLAGS" \
    --extra-ldflags="-sEXPORTED_RUNTIME_METHODS=getTempRet0,setTempRet0,addFunction,removeFunction,TTY,FS"
fi
emmake make -j"$(nproc)" qemu-system-arm

# 4. copy to web/
mkdir -p "$REPO/web"
cp qemu-system-arm "$REPO/web/qemu-system-arm.js"
cp qemu-system-arm.wasm qemu-system-arm.worker.js "$REPO/web/"
ls -la "$REPO/web"/qemu-system-arm.*
