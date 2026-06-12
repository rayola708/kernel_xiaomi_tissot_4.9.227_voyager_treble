#!/bin/bash

# ================= COLOR =================
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
white='\033[0m'

# ================= VARIANT =================
VARIANT=$1
if [ -z "$VARIANT" ]; then
    VARIANT="KSU" # Default fallback
fi

# ================= PATH =================
DEFCONFIG="tissot_defconfig"
TEMP_DEFCONFIG="tissot_temp_defconfig"
ROOTDIR=$(pwd)
OUTDIR="$ROOTDIR/out/arch/arm64/boot"
ANYKERNEL_DIR="$ROOTDIR/AnyKernel"
KIMG_DTB="$OUTDIR/Image.gz-dtb"
KIMG="$OUTDIR/Image.gz"

# ========== TOOLCHAIN (CLANG) ===========
export PATH="$ROOTDIR/clang-zyc/bin:$PATH"

# ================= INFO =================
KERNEL_NAME="Yoru-Treble"
DEVICE="tissot"

# =============== DATE (WIB) ===============
DATE_TITLE=$(TZ=Asia/Jakarta date +"%d%m%Y")
TIME_TITLE=$(TZ=Asia/Jakarta date +"%H%M%S")
BUILD_DATETIME=$(TZ=Asia/Jakarta date +"%d %B %Y")

# ================= TELEGRAM =================
TG_BOT_TOKEN="${TG_BOT_TOKEN}"
TG_CHAT_ID="${TG_CHAT_ID}"

# ================= GLOBAL =================
BUILD_TIME="unknown"
KERNEL_VERSION="unknown"
TC_INFO="unknown"
IMG_USED="unknown"
MD5_HASH="unknown"
ZIP_NAME=""

# ================= FUNCTION =================
clone_anykernel() {
    if [ ! -d "$ANYKERNEL_DIR" ]; then
        echo -e "$yellow[+] Cloning AnyKernel3...$white"
        git clone -b tissot https://github.com/rahmatsobrian/AnyKernel3.git "$ANYKERNEL_DIR" || exit 1
    fi
}

get_toolchain_info() {
    if command -v clang >/dev/null 2>&1; then
        if clang --version | grep -qi "zyc\|ZyCromerZ"; then
            CLANG_VER=$(clang --version | head -n1 | sed 's/.*version //')
            TC_INFO="ZyC Clang ${CLANG_VER}"
        else
            CLANG_VER=$(clang --version | head -n1)
            TC_INFO="Clang (${CLANG_VER})"
        fi
    else
        TC_INFO="unknown"
    fi
}

get_kernel_version() {
    if [ -f "Makefile" ]; then
        VERSION=$(grep -E '^VERSION =' Makefile | awk '{print $3}')
        PATCHLEVEL=$(grep -E '^PATCHLEVEL =' Makefile | awk '{print $3}')
        SUBLEVEL=$(grep -E '^SUBLEVEL =' Makefile | awk '{print $3}')
        KERNEL_VERSION="${VERSION}.${PATCHLEVEL}.${SUBLEVEL}"
    else
        KERNEL_VERSION="unknown"
    fi
}

send_telegram_error() {
    curl -s -X POST "https://api.telegram.org/bot${TG_BOT_TOKEN}/sendMessage" \
        -d chat_id="${TG_CHAT_ID}" \
        -d parse_mode=Markdown \
        -d text="❌ *Kernel CI Build Test Failed [${VARIANT}]*

📄 *Log attached below* "

    send_telegram_log
}

send_telegram_start() {
curl -s -X POST "https://api.telegram.org/bot${TG_BOT_TOKEN}/sendMessage" \
        -d chat_id="${TG_CHAT_ID}" \
        -d parse_mode=Markdown \
        -d text="🚀 *Kernel CI Build Test Started [${VARIANT}]* "
}

send_telegram_log() {
    LOG_FILE="$ROOTDIR/logs/build-${VARIANT}.txt"

    [ ! -f "$LOG_FILE" ] && return

    curl -s -X POST "https://api.telegram.org/bot${TG_BOT_TOKEN}/sendDocument" \
        -F chat_id="${TG_CHAT_ID}" \
        -F document=@"${LOG_FILE}" 
}

# ================= Build Kernel =================
build_kernel() {

echo -e "$yellow[+] Sending telegram start...$white"
send_telegram_start

echo -e "$yellow[+] Getting toolchain info...$white"
get_toolchain_info

echo -e "$yellow[+] Removing out folder...$white"
rm -rf out
    
echo -e "$yellow[+] Creating out folder...$white"
mkdir -p out

# === DYNAMIC DEFCONFIG SETUP ===
echo -e "$yellow[+] Preparing kernel config for ${VARIANT}...$white"
cp arch/arm64/configs/${DEFCONFIG} arch/arm64/configs/${TEMP_DEFCONFIG}

# Jika varian Non-KSU, matikan CONFIG_KSU secara dinamis
if [ "$VARIANT" == "Non-KSU" ]; then
    echo -e "$yellow[+] Stripping KSU configs for Non-KSU build...$white"
    sed -i 's/CONFIG_KSU=y/# CONFIG_KSU is not set/g' arch/arm64/configs/${TEMP_DEFCONFIG}
fi

make O=out ARCH=arm64 ${TEMP_DEFCONFIG} || {
    send_telegram_error
    exit 1
}

BUILD_START=$(TZ=Asia/Jakarta date +%s)

echo -e "$yellow[+] Building Kernel [${VARIANT}]...$white"
make -j$(nproc --all) \
  ARCH=arm64 \
  O=out \
  CC=clang \
  CROSS_COMPILE=aarch64-linux-gnu- \
  CROSS_COMPILE_ARM32=arm-linux-gnueabi- || {
        send_telegram_error
        exit 1
    }

BUILD_END=$(TZ=Asia/Jakarta date +%s)
DIFF=$((BUILD_END - BUILD_START))
BUILD_TIME="$((DIFF / 60)) min $((DIFF % 60)) sec"

echo -e "$yellow[+] Getting kernel version...$white"
get_kernel_version

# Menambahkan varian ke nama zip agar tidak tertukar
ZIP_NAME="${KERNEL_NAME}-${VARIANT}-${DEVICE}-${KERNEL_VERSION}-${DATE_TITLE}-${TIME_TITLE}.zip"
}

# =============== Zipping Kernel ===============
pack_kernel() {
    echo -e "$yellow[+] Packing AnyKernel...$white"

    clone_anykernel
    cd "$ANYKERNEL_DIR" || exit 1

    rm -f Image* *.zip

    if [ -f "$KIMG_DTB" ]; then
        cp "$KIMG_DTB" Image.gz-dtb
        IMG_USED="Image.gz-dtb"
    elif [ -f "$KIMG" ]; then
        cp "$KIMG" Image.gz
        IMG_USED="Image.gz"
    else
        send_telegram_error
        exit 1
    fi

echo -e "$yellow[+] Zipping kernel...$white"
    zip -r9 "$ZIP_NAME" . -x ".git*" "README.md"
    MD5_HASH=$(md5sum "$ZIP_NAME" | awk '{print $1}')

    echo -e "$green[✓] Zip created: $ZIP_NAME ($IMG_USED)$white"
}

# ============= Upload To Telegram =============
upload_telegram() {
    ZIP_PATH="$ANYKERNEL_DIR/$ZIP_NAME"
    [ ! -f "$ZIP_PATH" ] && return

    echo -e "$yellow[+] Uploading to Telegram...$white"

    curl -s -X POST "https://api.telegram.org/bot${TG_BOT_TOKEN}/sendDocument" \
        -F chat_id="${TG_CHAT_ID}" \
        -F document=@"${ZIP_PATH}" \
        -F parse_mode=Markdown \
        -F caption="🔥 *Kernel CI Build Test Success*

📱 *Device* : ${DEVICE}
📦 *Kernel Name* : ${KERNEL_NAME}
🏷️ *Variant* : ${VARIANT}
🍃 *Kernel Version* : ${KERNEL_VERSION}

🛠 *Toolchain* :
\`${TC_INFO}\`

⌛ *Build Time* : ${BUILD_TIME}
🕒 *Build Date* : ${BUILD_DATETIME}

🔐 *MD5* :
\`${MD5_HASH}\`

❓ *Need Test*"

send_telegram_log
}

# ================= RUN =================
START=$(TZ=Asia/Jakarta date +%s)

build_kernel
pack_kernel
upload_telegram

END=$(TZ=Asia/Jakarta date +%s)
echo -e "$green[✓] Done in $((END - START)) seconds$white"
