#!/bin/bash

# === [Konfigurasi Awal] ===
export ARCH=arm64
export SUBARCH=arm64
export CLANG_PATH=/home/mhdputerapmgks/toolchain/proton-clang
export KERNEL_DIR=$(pwd)
export OUT_DIR=out

# === [Export Toolchain Path] ===
export PATH="$CLANG_PATH/bin:$PATH"

# === [Cek keberadaan Clang] ===
if [ ! -f "$CLANG_PATH/bin/clang" ]; then
    echo "❌ Proton Clang tidak ditemukan di $CLANG_PATH"
    exit 1
fi

# === [Bersih-bersih build lama] ===
rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

# === [Generate defconfig] ===
make O="$OUT_DIR" tissot_defconfig

# === [Compile kernel menggunakan LLVM toolchain penuh] ===
make -j$(nproc) O="$OUT_DIR" \
    CC=clang \
    LLVM=1 \
    LLVM_IAS=1

# === [Cek hasil build] ===
KERNEL_IMG="$OUT_DIR/arch/arm64/boot/Image.gz-dtb"

if [ -f "$KERNEL_IMG" ]; then
    echo "✅ Build selesai! Kernel tersedia di:"
    echo "$KERNEL_IMG"
else
    echo "❌ Build gagal: Image.gz-dtb tidak ditemukan."
    exit 1
fi
