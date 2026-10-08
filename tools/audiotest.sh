#!/bin/sh
# Dev helper: build the audio self-test and render all songs / effects to
# WAV files in build/at/ (runs under Wine; no sound card needed).
set -e
cd "$(dirname "$0")/.."
mkdir -p build/at
nasm -f win64 -dAUDIO_TEST -I src/ -o build/at.obj src/main.asm
x86_64-w64-mingw32-ld -o build/at/audiotest.exe build/at.obj -e start --subsystem console \
    --image-base 0x400000 --disable-dynamicbase -L/usr/x86_64-w64-mingw32/lib \
    -lkernel32 -luser32 -lgdi32 -lwinmm
cd build/at && WINEDEBUG=-all wine audiotest.exe && ls -la *.wav
