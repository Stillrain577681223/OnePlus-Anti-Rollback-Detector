#!/system/bin/sh

CURRENT_DIR=$(pwd)
EXPECTED_SHA256="b8f7f4af222b94c5550e4000fc6b9933e67cdbd9e1acbfd0af42c2feb922327c"
# Do NOT run in Android/data directory or path containing "zip"
CURRENT_DIR_LOWER=$(echo "$CURRENT_DIR" | tr 'A-Z' 'a-z')

echo "$CURRENT_DIR_LOWER" | grep -qE "^/storage/emulated/0/android/data/|zip"
if [ $? -eq 0 ]; then
    echo "============================================"
    echo " ❌ Error: Please extract the entire ZIP first before running!"
    echo " Do NOT run directly inside the archive!"
    echo "============================================"
    exit 1
fi


su -c "dd if=/dev/zero of=/sdcard/__test__ bs=1 count=1 >/dev/null 2>&1" >/dev/null 2>&1
if [ $? -eq 0 ]; then
  ENV="system"
  su -c "rm -f /sdcard/__test__ >/dev/null 2>&1" >/dev/null 2>&1
else
  ENV="mt_ext"
fi
if [ "$ENV" = "mt_ext" ]; then
  echo "❌ Current environment: MT Manager Extension (not supported)"
  echo "Please switch to MT Manager system environment"
  exit 1
fi

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'
echo "————————————————————"
echo "OnePlus Anti-Rollback Checker ver1.6"
echo "Author: Github/XDAForum/Telegram @Stillrain-001"
echo "Partial technical support & code improvements by Github@Bartixxx"
echo "Welcome to Bartixxx's ARB query website"
echo "https://oneplusantiroll.netlify.app"
echo
echo "${YELLOW}This detection method was first published by me, licensed under MIT.${NC}"
echo "${YELLOW}Please report unauthorized direct copying without credit.${NC}"
echo ""
echo "${YELLOW}Disclaimer:${NC}"
echo "${YELLOW}This tool only extracts xbl_config partition and analyzes ARB status.${NC}"
echo "${YELLOW}It does NOT modify system behavior, and takes no responsibility for flashing risks.${NC}"
echo ""
echo "${YELLOW}If you agree to the check, please wait.${NC}"
echo "${YELLOW}If not, exit the program now.${NC}"
echo "${YELLOW}If the program exits without output, run it again. If still no result, report on Coolapk.${NC}"
echo "${YELLOW}The program will start automatically in 7 seconds.${NC}"
for i in 7 6 5 4 3 2 1; do
  echo -n "$i… "
  sleep 1
done
echo ""
echo "————————————————————"
# Current boot slot
SLOT=$(getprop ro.boot.slot_suffix 2>/dev/null)
PART="/dev/block/by-name/xbl_config${SLOT}"

if ! su -c cat "$PART" > /dev/null 2>&1; then
    echo "Partition not found!"
    exit 1
fi

# Looking for arbextract (replaces old arbscan)
echo "Searching for arbextract, please wait..."
# Get script directory
SCRIPT_DIR=$(dirname "$0")

BIN=$(find "$SCRIPT_DIR" -type f -name arbextract 2>/dev/null | head -n 1)

[ -z "$BIN" ] && BIN=$(find /storage/emulated/0/Download -type f -name arbextract 2>/dev/null | head -n 1)

[ -z "$BIN" ] && BIN=$(find /storage/emulated/0 \
-type d \( -name "DCIM" -o -name "Pictures" -o -name "Movies" -o -name "Android" \) -prune -o \
-type f -name "arbextract" -print 2>/dev/null | head -n 1)

NEED_COPY=1
# Check if file found, thanks to Github@Bartixxx
#———————————————————————
if [ -z "$BIN" ]; then
    echo "Local arbextract not found, downloading from Gitee (CN mirror)..."
    DL_PATH="$(pwd)/arbextract"
    URL="https://gitee.com/Stillrain001/OnePlus-Anti-Rollback-Detector/raw/main/arbextract"

    if curl --help >/dev/null 2>&1; then
        curl -sL "$URL" -o "$DL_PATH"
    elif wget --help >/dev/null 2>&1; then
        wget -q "$URL" -O "$DL_PATH"
    else
        echo "Download failed (missing curl/wget)."
        exit 1
    fi


    FILE_SHA256=$(sha256sum "$DL_PATH" 2>/dev/null | awk '{print $1}')
    SHA256_INVALID=0

    if [ "$FILE_SHA256" != "$EXPECTED_SHA256" ]; then
        echo "File checksum mismatch"
        echo ""
        rm -f "$DL_PATH"
        SHA256_INVALID=1
    else
        echo "File checksum OK"
    fi

    # Checksum invalid → try GitHub
    if [ $SHA256_INVALID -eq 1 ] || [ ! -f "$DL_PATH" ]; then
        echo "Download failed!"
        echo "Trying GitHub mirror..."
        URL="https://raw.githubusercontent.com/Stillrain577681223/OnePlus-Anti-Rollback-Detector/main/arbextract"

        if curl --help >/dev/null 2>&1; then
            curl -sL "$URL" -o "$DL_PATH"
        elif wget --help >/dev/null 2>&1; then
            wget -q "$URL" -O "$DL_PATH"
        else
            echo "Download failed (missing curl/wget)."
            exit 1
        fi

        if [ -f "$DL_PATH" ]; then
            BIN="$DL_PATH"
            chmod +x "$BIN"
            echo "Download successful."
            FILE_SHA256=$(sha256sum "$BIN" 2>/dev/null | awk '{print $1}')

            if [ "$FILE_SHA256" != "$EXPECTED_SHA256" ]; then
                echo "File checksum mismatch"
                echo ""
                rm -f "$DL_PATH"
                exit 1
            else
                echo "File checksum OK"
            fi
        else
            echo "Download failed!"
            exit 1
        fi
    else
        BIN="$DL_PATH"
        chmod +x "$BIN"
        echo "Download successful."
    fi

    # Copy to /data/local/tmp
    if [ $NEED_COPY -eq 1 ] && [ -n "$BIN" ]; then
        TMP_BIN="/data/local/tmp/arbextract"
        su -c "cp \"$BIN\" \"$TMP_BIN\" >/dev/null 2>&1" || { echo "Error copying to working directory!"; exit 1; }
        BIN="$TMP_BIN"
        NEED_COPY=0
    fi

else
    echo "Found: $BIN"

    FILE_SHA256=$(sha256sum "$BIN" 2>/dev/null | awk '{print $1}')

    if [ "$FILE_SHA256" != "$EXPECTED_SHA256" ]; then
        echo "File checksum mismatch"
        rm -f "$BIN"
        BIN=""
    else
        echo "File checksum OK"
    fi
fi

# Local file invalid → redownload
if [ -z "$BIN" ]; then
    echo "Local file invalid, redownloading from Gitee..."
    DL_PATH="$(pwd)/arbextract"
    URL="https://gitee.com/Stillrain001/OnePlus-Anti-Rollback-Detector/raw/main/arbextract"

    if curl --help >/dev/null 2>&1; then
        curl -sL "$URL" -o "$DL_PATH"
    elif wget --help >/dev/null 2>&1; then
        wget -q "$URL" -O "$DL_PATH"
    else
        echo "Download failed (missing curl/wget)."
        exit 1
    fi

    FILE_SHA256=$(sha256sum "$DL_PATH" 2>/dev/null | awk '{print $1}')
    SHA256_INVALID=0

    if [ "$FILE_SHA256" != "$EXPECTED_SHA256" ]; then
        echo "File checksum mismatch"
        echo ""
        rm -f "$DL_PATH"
        SHA256_INVALID=1
    else
        echo "File checksum OK"
    fi

    if [ $SHA256_INVALID -eq 1 ] || [ ! -f "$DL_PATH" ]; then
        echo "Download failed!"
        echo "Trying GitHub mirror..."
        URL="https://raw.githubusercontent.com/Stillrain577681223/OnePlus-Anti-Rollback-Detector/main/arbextract"

        if curl --help >/dev/null 2>&1; then
            curl -sL "$URL" -o "$DL_PATH"
        elif wget --help >/dev/null 2>&1; then
            wget -q "$URL" -O "$DL_PATH"
        else
            echo "Download failed (missing curl/wget)."
            exit 1
        fi

        if [ -f "$DL_PATH" ]; then
            BIN="$DL_PATH"
            chmod +x "$BIN"
            echo "Download successful."
            FILE_SHA256=$(sha256sum "$BIN" 2>/dev/null | awk '{print $1}')

            if [ "$FILE_SHA256" != "$EXPECTED_SHA256" ]; then
                echo "File checksum mismatch"
                echo ""
                rm -f "$DL_PATH"
                exit 1
            fi
        else
            echo "Download failed!"
            exit 1
        fi
    else
        BIN="$DL_PATH"
        chmod +x "$BIN"
        echo "Download successful."
    fi

    if [ $NEED_COPY -eq 1 ] && [ -n "$BIN" ]; then
        TMP_BIN="/data/local/tmp/arbextract"
        su -c "cp \"$BIN\" \"$TMP_BIN\" >/dev/null 2>&1" || { echo "Error copying to working directory!"; exit 1; }
        BIN="$TMP_BIN"
        NEED_COPY=0
        echo "$BIN"
    fi
fi

# Final copy to tmp
if [ $NEED_COPY -eq 1 ] && [ -n "$BIN" ]; then
    TMP_BIN="/data/local/tmp/arbextract"
    su -c "cp \"$BIN\" \"$TMP_BIN\" >/dev/null 2>&1" || { echo "Error copying to working directory!"; exit 1; }
    BIN="$TMP_BIN"
    NEED_COPY=0
fi

echo
# Dump partition image
IMAGE_PATH="/data/local/tmp/xbl_config${SLOT}.img"
echo "Extracting image, please wait..."
su -c "dd if=/dev/block/by-name/xbl_config${SLOT} of=${IMAGE_PATH} bs=4096 >/dev/null 2>&1" 2>&1

if [ $? -eq 0 ]; then
    echo "Image extracted successfully"
else
    echo "Error extracting image, but continuing script."
fi

# Ensure binary in tmp
TMP_BIN="/data/local/tmp/arbextract"
if [ $NEED_COPY -eq 1 ]; then
  if [ "$BIN" != "$TMP_BIN" ]; then
    su -c "cp \"$BIN\" \"$TMP_BIN\" >/dev/null 2>&1" || { echo "Error copying to working directory!"; exit 1; }
    NEED_COPY=0
  fi
fi
# Set executable permission
su -c "chmod +x \"$TMP_BIN\" >/dev/null 2>&1" || { echo "Error setting execute permission!"; exit 1; }

echo "Image extraction done, running check... please wait"
echo
# Show build info
BUILD_ID=$(getprop ro.build.display.id)
echo "Device build ID: $BUILD_ID"
echo "Current slot: ${SLOT}"

# Safe devices (no ARB)
DEVICE_NAME="Device"
SAFE_DEVICE=0

case "$BUILD_ID" in
  *PLK110*|*CPH2747*|*CPH2745*)
    DEVICE_NAME="OnePlus 15"
    SAFE_DEVICE=1
    ;;
  *PLQ110*)
    DEVICE_NAME="OnePlus Ace6"
    SAFE_DEVICE=1
    ;;
  *PLR110*)
    DEVICE_NAME="OnePlus Ace6T"
    SAFE_DEVICE=1
    ;;
  *)
    DEVICE_NAME=""
    SAFE_DEVICE=0
    ;;
esac

# ==============================
# Safe device: exit normally
# ==============================
if [ $SAFE_DEVICE -eq 1 ]; then
  echo "----------------------------------------"
  echo "✅ ${DEVICE_NAME} series has no ARB protection"
  echo "----------------------------------------"
  su -c rm -f "$IMAGE_PATH" >/dev/null 2>&1
fi

# ==============================
# Run ARB check
# ==============================
echo "Running detection..."
echo "————————————————————"
echo
# Run detection
FULL_OUTPUT=$(echo N | su -c "$TMP_BIN" "$IMAGE_PATH" 2>&1)

if [ -z "$FULL_OUTPUT" ]; then
    echo "❌ Check failed: arbextract returned no output"
    echo "Your environment may not be supported."
    su -c rm -f "$IMAGE_PATH" >/dev/null 2>&1
    exit 1
fi

echo "==============================="
echo "ARB Check Result:"
echo "$FULL_OUTPUT" | grep -E "OEM Metadata Major Version:|OEM Metadata Minor Version:|ARB \(Anti-Rollback\):"

# Parse ARB index
IDX=$(echo "$FULL_OUTPUT" | grep "ARB (Anti-Rollback)" | tr -d ' ' | awk -F: '{print $2}')
echo "↓ Raw output (invalid if this line missing; ≥1 = Activated, 0 = Deactivated)"
echo "$FULL_OUTPUT" | grep "Anti-Rollback"

su -c rm -f "$IMAGE_PATH" >/dev/null 2>&1

if [ -n "$IDX" ]; then
    if [ "$IDX" = "0" ]; then
echo "==============================="
        echo -e "Anti-Rollback is \033[0;32mNOT Activated\033[0m"
        echo "Dimensity devices have hidden ARB; this is NOT a reliable reference!"
    else
echo "==============================="
        echo -e "Anti-Rollback is \033[0;31mActivated\033[0m"
        echo -e "DO NOT downgrade via flashing, or you will brick the device!"
    fi
else
echo "==============================="
    echo -e "\033[1;33mCould not detect ARB status\033[0m"
    echo -e "ARB Index returned empty. Check if arbextract is valid."
    echo "Full log:"
    echo "$FULL_OUTPUT"
fi
echo "==============================="
sync
