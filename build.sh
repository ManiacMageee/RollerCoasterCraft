#!/bin/sh
# Build RollerCoasterCraft.exe (Windows x64) with NASM + MinGW ld.
# Works on Linux, macOS (brew install nasm mingw-w64) and in CI.
set -e
cd "$(dirname "$0")"
LD=${LD:-x86_64-w64-mingw32-ld}
LIBDIR=${LIBDIR:-$(dirname "$(x86_64-w64-mingw32-gcc -print-libgcc-file-name 2>/dev/null || echo /usr/x86_64-w64-mingw32/lib/x)")}
[ -f "$LIBDIR/libkernel32.a" ] || LIBDIR=/usr/x86_64-w64-mingw32/lib
mkdir -p build
nasm -f win64 -I src/ -l build/main.lst -o build/main.obj src/main.asm
"$LD" -o RollerCoasterCraft.exe build/main.obj -e start --subsystem windows \
    --image-base 0x400000 --disable-dynamicbase --disable-high-entropy-va \
    --stack 0x400000,0x400000 \
    -Map build/main.map -L"$LIBDIR" -lkernel32 -luser32 -lgdi32 -lwinmm
echo "built RollerCoasterCraft.exe"
