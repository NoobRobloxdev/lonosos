@echo off
echo Assembling Bootloader...
nasm.exe -f bin boot.asm -o boot.bin

echo Assembling Kernel...
nasm.exe -f bin kernel.asm -o kernel.bin

echo Linking into OS Image...
copy /b boot.bin + kernel.bin lonos2.img

echo Done! Image created: lonos2.img
pause