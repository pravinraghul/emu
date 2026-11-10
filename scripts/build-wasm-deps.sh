#!/usr/bin/env bash
# Build QEMU's library dependencies (zlib, libffi, pcre2, glib) for Emscripten.
# Native (no Docker) port of the recipe in ktock/qemu-wasm's Dockerfile.
# All sources come from GitHub (zlib.net / gnome.org / freedesktop.org are not
# required). pixman is skipped: it is optional for QEMU and unused here.
#
# Usage: scripts/build-wasm-deps.sh            (uses $BUILD_ROOT, default ~/build)
set -euo pipefail

BUILD_ROOT="${BUILD_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)/build}"
EMSDK="${EMSDK:-$BUILD_ROOT/emsdk}"
SRC="$BUILD_ROOT/deps-src"
export TARGET="$BUILD_ROOT/wasm-target"

ZLIB_VERSION=1.3.1
GLIB_MINOR_VERSION=2.75
GLIB_VERSION=${GLIB_MINOR_VERSION}.0
PCRE2_VERSION=10.40
GVDB_REV=0854af0fdb6d527a8d1999835ac2c5059976c210
FFI_VERSION=adbcf2b247696dde2667ab552cb93e0c79455c84

# shellcheck disable=SC1091
source "$EMSDK/emsdk_env.sh" >/dev/null

BASE_CFLAGS="-O2 -matomics -mbulk-memory -DNDEBUG -sWASM_BIGINT -DWASM_BIGINT -pthread -sMALLOC=mimalloc -sASYNCIFY=1"
export CFLAGS="$BASE_CFLAGS" CXXFLAGS="$BASE_CFLAGS"
export LDFLAGS="-L$TARGET/lib -O2"
export CPATH="$TARGET/include"
export PKG_CONFIG_PATH="$TARGET/lib/pkgconfig"
export EM_PKG_CONFIG_PATH="$PKG_CONFIG_PATH"
export CHOST="wasm32-unknown-linux"
export MAKEFLAGS="-j$(nproc)"

mkdir -p "$SRC" "$TARGET/lib" "$TARGET/include"

# --- zlib -------------------------------------------------------------------
if [ ! -f "$TARGET/lib/libz.a" ]; then
  rm -rf "$SRC/zlib" && mkdir -p "$SRC/zlib"
  curl -fLs "https://github.com/madler/zlib/releases/download/v$ZLIB_VERSION/zlib-$ZLIB_VERSION.tar.gz" | tar xzC "$SRC/zlib" --strip-components=1
  (cd "$SRC/zlib" && emconfigure ./configure --prefix="$TARGET" --static && make install)
fi

# --- libffi -----------------------------------------------------------------
if [ ! -f "$TARGET/lib/libffi.a" ]; then
  rm -rf "$SRC/libffi"
  git clone -q https://github.com/libffi/libffi "$SRC/libffi"
  (cd "$SRC/libffi" && git checkout -q "$FFI_VERSION" && autoreconf -fiv >/dev/null &&
   LDFLAGS="$LDFLAGS -sEXPORTED_RUNTIME_METHODS='getTempRet0,setTempRet0'" \
   emconfigure ./configure --host="$CHOST" --prefix="$TARGET" --enable-static --disable-shared \
     --disable-dependency-tracking --disable-builddir --disable-multi-os-directory \
     --disable-raw-api --disable-structs --disable-docs &&
   emmake make install SUBDIRS='include')
fi

# --- libresolv stub ---------------------------------------------------------
if [ ! -f "$TARGET/lib/libresolv.a" ]; then
  mkdir -p "$SRC/stub"
  cat > "$SRC/stub/res_query.c" <<'EOT'
#include <netdb.h>
int res_query(const char *name, int class, int type, unsigned char *dest, int len)
{
    h_errno = HOST_NOT_FOUND;
    return -1;
}
EOT
  emcc $CFLAGS -c "$SRC/stub/res_query.c" -fPIC -o "$SRC/stub/libresolv.o"
  emar rcs "$TARGET/lib/libresolv.a" "$SRC/stub/libresolv.o"
fi

# --- pcre2 (glib dependency) -----------------------------------------------
if [ ! -f "$TARGET/lib/libpcre2-8.a" ]; then
  rm -rf "$SRC/pcre2" && mkdir -p "$SRC/pcre2"
  curl -fLs "https://github.com/PhilipHazel/pcre2/releases/download/pcre2-$PCRE2_VERSION/pcre2-$PCRE2_VERSION.tar.bz2" | tar xjC "$SRC/pcre2" --strip-components=1
  (cd "$SRC/pcre2" && emconfigure ./configure --host="$CHOST" --prefix="$TARGET" --enable-static --disable-shared \
     --disable-jit --disable-pcre2grep-libz --disable-pcre2grep-libbz2 && emmake make install)
fi

# --- glib -------------------------------------------------------------------
if [ ! -f "$TARGET/lib/libglib-2.0.a" ]; then
  rm -rf "$SRC/glib"
  git clone -q --depth 1 --branch "$GLIB_VERSION" https://github.com/GNOME/glib "$SRC/glib"
  rm -rf "$SRC/glib/subprojects/gvdb"
  git clone -q https://github.com/GNOME/gvdb "$SRC/glib/subprojects/gvdb"
  git -C "$SRC/glib/subprojects/gvdb" checkout -q "$GVDB_REV"
  cat > "$SRC/emcc-meson-wrap.sh" <<'EOT'
#!/bin/bash
# emscripten ignores some -s flags at compile time with a warning; meson's
# checks would fail on -Werror=unused-command-line-argument.
set -euo pipefail
cmd="$1"; shift
new_args=()
for arg in "$@"; do new_args+=("${arg//-Werror=unused-command-line-argument/-Wno-error=unused-command-line-argument}"); done
"$cmd" "${new_args[@]}"
EOT
  cat > "$SRC/cross.meson" <<EOT
[host_machine]
system = 'emscripten'
cpu_family = 'wasm32'
cpu = 'wasm32'
endian = 'little'

[binaries]
c = ['bash', '$SRC/emcc-meson-wrap.sh', 'emcc']
cpp = ['bash', '$SRC/emcc-meson-wrap.sh', 'em++']
ar = 'emar'
ranlib = 'emranlib'
pkgconfig = ['pkg-config', '--static']
EOT
  (cd "$SRC/glib" &&
   CFLAGS="-Wno-error=incompatible-function-pointer-types -Wincompatible-function-pointer-types $BASE_CFLAGS" \
   CXXFLAGS="-Wno-error=incompatible-function-pointer-types -Wincompatible-function-pointer-types $BASE_CFLAGS" \
   meson setup _build --prefix="$TARGET" --cross-file="$SRC/cross.meson" --default-library=static \
     --buildtype=release --wrap-mode=nodownload --force-fallback-for=gvdb -Dselinux=disabled -Dxattr=false \
     -Dlibmount=disabled -Dnls=disabled -Dtests=false -Dglib_assert=false -Dglib_checks=false &&
   for d in HAVE_CLOSE_RANGE HAVE_EPOLL_CREATE HAVE_KQUEUE HAVE_POSIX_SPAWN HAVE_FALLOCATE; do
     sed -i -E "/#define $d 1/d" _build/config.h
   done &&
   meson install -C _build)
fi

echo "wasm deps installed in $TARGET"
