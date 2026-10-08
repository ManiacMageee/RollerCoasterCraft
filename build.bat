@echo off
rem Build RollerCoasterCraft.exe on Windows.
rem Needs NASM and a MinGW-w64 toolchain (for ld and the import libraries) on PATH.
if not exist build mkdir build
nasm -f win64 -I src\ -o build\main.obj src\main.asm || goto :error
ld -o RollerCoasterCraft.exe build\main.obj -e start --subsystem windows --image-base 0x400000 --disable-dynamicbase --disable-high-entropy-va --stack 0x400000,0x400000 -lkernel32 -luser32 -lgdi32 -lwinmm || goto :error
echo Built RollerCoasterCraft.exe
goto :eof
:error
echo Build failed.
exit /b 1
