#!/bin/bash

# === Konfigurasi ===
ANYKERNEL_DIR="AnyKernel3"
OUTPUT_ZIP="Voyager-Kernel-Non-Trele-$(date +%Y%m%d-%H%M).zip"
BOT_TOKEN="-"
CHAT_ID="-"

# Lokasi hasil build kernel
KERNEL_BUILD_DIR="out/arch/arm64/boot"
IMAGE_DTB="Image.gz-dtb"

# === Pengecekan awal ===
if [ ! -d "$ANYKERNEL_DIR" ]; then
    echo "[!] Folder $ANYKERNEL_DIR tidak ditemukan!"
    exit 1
fi

if [ -z "$BOT_TOKEN" ] || [ -z "$CHAT_ID" ]; then
    echo "[!] BOT_TOKEN atau CHAT_ID belum diisi!"
    exit 1
fi

if [ ! -f "$KERNEL_BUILD_DIR/$IMAGE_DTB" ]; then
    echo "[!] File $IMAGE_DTB tidak ditemukan di $KERNEL_BUILD_DIR!"
    exit 1
fi

# Copy Image.gz-dtb ke AnyKernel3
cp "$KERNEL_BUILD_DIR/$IMAGE_DTB" "$ANYKERNEL_DIR/"

# === Packing ZIP ===
echo "[*] Mem-packing AnyKernel3 ke ZIP..."
cd "$ANYKERNEL_DIR" || exit
zip -r9 "../$OUTPUT_ZIP" ./* > /dev/null
cd ..

echo "[+] ZIP berhasil dibuat: $OUTPUT_ZIP"

# === Caption Telegram ===
CAPTION="📦 New Build Voyager
🧾 File: $OUTPUT_ZIP
📝 Changelog:
• Compile with Clang 15
• Merge CAF tag LA.UM.8.6.2.c29-07900-89xx.0"

# === Kirim ke Telegram ===
echo "[*] Mengirim ZIP ke Telegram..."

curl -s -F document=@"$OUTPUT_ZIP" \
     -F chat_id="$CHAT_ID" \
     -F caption="$CAPTION" \
     "https://api.telegram.org/bot$BOT_TOKEN/sendDocument"

echo
