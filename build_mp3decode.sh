#!/bin/bash
# Cross-compile mp3decode for MIPS (WiFi Pineapple Pager)
# Run inside the OpenWrt SDK Docker container
set -e

export PATH=/builder/staging_dir/toolchain-mipsel_24kc_gcc-11.2.0_musl/bin:$PATH
export STAGING_DIR=/builder/staging_dir
CC=mipsel-openwrt-linux-musl-gcc
STRIP=mipsel-openwrt-linux-musl-strip

cd /tmp/mp3build

# Download minimp3 header if not present
if [ ! -f minimp3.h ]; then
    echo "[+] Downloading minimp3.h..."
    wget -q "https://raw.githubusercontent.com/lieff/minimp3/master/minimp3.h" -O minimp3.h
fi

echo "[+] Compiling mp3decode..."
$CC -O2 -static -o mp3decode mp3decode.c -lm

echo "[+] Stripping..."
$STRIP mp3decode

echo "[+] Done!"
ls -la mp3decode
file mp3decode
