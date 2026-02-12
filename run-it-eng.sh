#!/system/bin/sh

# OnePlus Anti-Rollback Checker
# Author: Stillrain-001 (Jing Yuxuan)
# Copyright (c) 2026 Stillrain
# Licensed under MIT License

# This script uses the 'arbscan' binary:
# Original Author: SyedInSaf
# Repository: https://github.com/SyedInSaf/arbscan
# License: Apache License 2.0
# arbscan is a general Android tool, not limited to OnePlus devices.

su -c "dd if=/dev/zero of=/sdcard/__test__ bs=1 count=1" >/dev/null 2>&1
if [ $? -eq 0 ]; then
  ENV="system"
  su -c "rm -f /sdcard/__test__" >/dev/null 2>&1
else
  ENV="mt_ext"
fi

if [ "$ENV" = "mt_ext" ]; then
  echo "❌ Current environment: MT Extension (not supported)"
  echo "Please switch to MT System Shell."
  exit 1
fi

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "————————————————————"
echo -e "OnePlus Anti-Rollback Checker"
echo -e "Author: Stillrain-001"
echo -e "${YELLOW}This detection method was first published by me.${NC}"
echo -e "${YELLOW}Licensed under MIT License.${NC}"
echo -e "${YELLOW}If you find anyone redistributing without credit, please contact me.${NC}"
echo ""
echo -e "${YELLOW}Disclaimer:${NC}"
echo -e "${YELLOW}This tool only extracts xbl_config partition and analyzes ARB status.${NC}"
echo -e "${YELLOW}It does NOT modify your system.${NC}"
echo -e "${YELLOW}I am NOT responsible for any risks caused by flashing.${NC}"
echo ""
echo -e "${YELLOW}If you agree, wait.${NC}"
echo -e "${YELLOW}If not, close this script now.${NC}"
echo -e "${YELLOW}Starting automatically in 7 seconds...${NC}"

for i in 7 6 5 4 3 2 1; do
  echo -n "$i… "
  sleep 1
done

echo ""
echo "————————————————————"

SLOT=$(getprop ro.boot.slot_suffix 2>/dev/null)
PART="/dev/block/by-name/xbl_config${SLOT}"

if ! su -c cat "$PART" > /dev/null 2>&1; then
    echo "Partition not found!"
    exit 1
fi

echo "Searching for arbscan, please wait..."

SCRIPT_DIR=$(dirname "$0")

BIN=$(find "$SCRIPT_DIR" -type f -name arbscan 2>/dev/null | head -n 1)
[ -z "$BIN" ] && BIN=$(find /storage/emulated/0/Download -type f -name arbscan 2>/dev/null | head -n 1)
[ -z "$BIN" ] && BIN=$(find /storage/emulated/0 -type f -name arbscan \
    ! -path "/storage/emulated/0/DCIM/*" \
    ! -path "/storage/emulated/0/Pictures/*" \
    ! -path "/storage/emulated/0/Movies/*" \
    ! -path "/storage/emulated/0/Android/*" 2>/dev/null | head -n 1)

if [ -z "$BIN" ]; then
    echo "arbscan not found locally. Downloading..."
    # Download to current directory and keep it
    DL_PATH="$(pwd)/arbscan"
    URL="https://raw.githubusercontent.com/Stillrain577681223/OnePlus-Anti-Rollback-Detector/main/arbscan"
    
    if curl --help >/dev/null 2>&1; then
        curl -sL "$URL" -o "$DL_PATH"
    elif wget --help >/dev/null 2>&1; then
        wget -q "$URL" -O "$DL_PATH"
    else
        echo "ERR: Failed to download arbscan (curl/wget missing)."
        exit 1
    fi

    if [ -f "$DL_PATH" ]; then
        BIN="$DL_PATH"
        chmod +x "$BIN"
        echo "Download successful."
        
        # Copy to /data/local/tmp for execution (required on some Android versions)
        # We KEEP the downloaded file in current dir for next time
        TMP_BIN="/data/local/tmp/arbscan"
        su -c "cp \"$BIN\" \"$TMP_BIN\"" || { echo "Failed to copy to working directory!"; exit 1; }
        BIN="$TMP_BIN"
    else
        echo "ERR: Download failed!"
        exit 1
    fi
else
    echo "Found: $BIN"
fi

IMAGE_PATH="/data/local/tmp/xbl_config${SLOT}.img"
echo "Extracting image, please wait..."
su -c "dd if=/dev/block/by-name/xbl_config${SLOT} of=${IMAGE_PATH} bs=4096" &>/dev/null
sleep 0.1

if [ $? -eq 0 ]; then
    echo "Image extracted successfully"
else
    echo "Error extracting image, but continuing..."
fi

TMP_BIN="/data/local/tmp/arbscan"
if [ "$BIN" != "$TMP_BIN" ]; then
    su -c "cp \"$BIN\" \"$TMP_BIN\"" || { echo "Failed to copy to working directory!"; exit 1; }
fi
su -c "chmod +x \"$TMP_BIN\"" || { echo "Failed to set execute permission!"; exit 1; }

echo "Image ready, starting detection..."
echo "——————————————————"

BUILD_ID=$(getprop ro.build.display.id)
echo "Device Build: $BUILD_ID"
echo "Current Slot: ${SLOT}"

FULL_OUTPUT=$(echo N | su -c "$TMP_BIN" "$IMAGE_PATH" 2>&1 | grep "ARB Index")
echo "$FULL_OUTPUT"

IDX=$(echo "$FULL_OUTPUT" | awk -F: '/ARB Index/{gsub(/ /,"");print $2}')

su -c rm -f "$IMAGE_PATH"

if [ "$IDX" = "0" ]; then
    echo -e "Anti-Rollback ${GREEN}Disabled${NC}"
    echo "Note: Dimensity devices may have hidden ARB, take result carefully."
else
    echo -e "Anti-Rollback ${RED}Enabled${NC}"
    echo "DO NOT downgrade your device — you may brick it permanently!"
fi
