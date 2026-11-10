#!/bin/bash
# Compila o nucleo mGBA (interface libretro) como biblioteca estatica para iOS (arm64).
set -euxo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MGBA_TAG="0.10.5"
WORK="$ROOT/build"

mkdir -p "$WORK/mgba"
if [ ! -d "$WORK/mgba-src" ]; then
  git clone --depth 1 --branch "$MGBA_TAG" https://github.com/mgba-emu/mgba.git "$WORK/mgba-src"
fi

# Cabecalho da interface libretro (usado pela ponte em C).
cp "$WORK/mgba-src/src/platform/libretro/libretro.h" "$ROOT/Sources/Bridge/libretro.h"

# O alvo libretro do CMake e uma biblioteca dinamica; precisamos de uma estatica para embutir no app.
sed -i '' 's/add_library(${BINARY_NAME}_libretro SHARED/add_library(${BINARY_NAME}_libretro STATIC/' "$WORK/mgba-src/CMakeLists.txt"
grep -n "_libretro STATIC" "$WORK/mgba-src/CMakeLists.txt"

# Com try_compile estatico (necessario para iOS) toda checagem de funcao "passa". O popcount32
# nao existe na libc: o mGBA tem uma versao propria, que so e usada se esse teste falhar.
sed -i '' '/find_function(popcount32)/d' "$WORK/mgba-src/CMakeLists.txt"
! grep -n "find_function(popcount32)" "$WORK/mgba-src/CMakeLists.txt"

rm -rf "$WORK/mgba-cmake"
cmake -S "$WORK/mgba-src" -B "$WORK/mgba-cmake" \
  -DCMAKE_SYSTEM_NAME=iOS \
  -DCMAKE_OSX_SYSROOT=iphoneos \
  -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=15.0 \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY \
  -DBUILD_LIBRETRO=ON \
  -DSKIP_LIBRARY=ON \
  -DDISABLE_DEPS=ON \
  -DDISABLE_FRONTENDS=ON \
  -DBUILD_QT=OFF -DBUILD_SDL=OFF \
  -DBUILD_GL=OFF -DBUILD_GLES2=OFF -DBUILD_GLES3=OFF -DUSE_EPOXY=OFF \
  -DUSE_DISCORD_RPC=OFF -DENABLE_SCRIPTING=OFF \
  -DUSE_FFMPEG=OFF -DUSE_ZLIB=OFF -DUSE_MINIZIP=OFF -DUSE_PNG=OFF \
  -DUSE_LIBZIP=OFF -DUSE_SQLITE3=OFF -DUSE_ELF=OFF -DUSE_LZMA=OFF \
  -DUSE_EDITLINE=OFF -DUSE_DEBUGGERS=OFF -DUSE_GDB_STUB=OFF

cmake --build "$WORK/mgba-cmake" --target mgba_libretro -j "$(sysctl -n hw.ncpu)"

LIB="$(find "$WORK/mgba-cmake" -name 'mgba_libretro*.a' | head -n 1)"
echo "Biblioteca encontrada: $LIB"
test -n "$LIB"
cp "$LIB" "$WORK/mgba/mgba_libretro.a"
lipo -info "$WORK/mgba/mgba_libretro.a" || true
