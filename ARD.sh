#!/system/bin/sh

EXPECTED_ZIP_SHA256="870002223df18d67b0790fa781516c1ddc4a3c39cf08ae8455ab3e1e4640066d"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

WORK_DIR="/data/local/tmp/arb_check"
OUTPUT_FILE="xbl_config.img"
MARKER="__ARCHIVE_FOLLOWS__"
IS_MEDIATEK=0
BUSYBOX_CMD="busybox"
CANDIDATE_BASES="/dev/block/bootdevice/by-name /dev/block/platform/*/by-name /dev/block/by-name"
ACTIVE_SLOT=""
PARTITION_PATH=""
BIN_PATH=""

cleanup() {
    if command -v su >/dev/null 2>&1; then
        su -c "rm -rf \"$WORK_DIR\"" 2>/dev/null
    else
        rm -rf "$WORK_DIR" 2>/dev/null
    fi
}

check_environment() {
    CURRENT_DIR=$(pwd)
    printf "%s\n" "$CURRENT_DIR" | grep -qE "^/storage/emulated/0/Android/data/|zip"
    if [ $? -eq 0 ]; then
        echo "============================================"
        echo " ❌Error: Please extract the entire zip file before running!"
        echo " Do not run directly inside the compressed package!"
        echo "============================================"
        exit 1
    fi

    command -v su >/dev/null 2>&1 || {
        echo "❌ Error: su command not found, root permission required"
        exit 1
    }

    _shell_type="unknown"
    if [ -n "${KSH_VERSION}" ]; then
        case "${KSH_VERSION}" in
            *MIRBSD*|*@\(#\)MIRBSD*) _shell_type="mksh" ;;
            *) _shell_type="ksh" ;;
        esac
    elif [ -n "${BASH_VERSION}" ]; then
        _shell_type="bash"
    elif (eval 'echo "${.sh.version}"' >/dev/null 2>&1); then
        _shell_type="mksh"
    elif [ -L "/system/bin/sh" ]; then
        _target=$(readlink "/system/bin/sh" 2>/dev/null || LC_ALL=C ls -l "/system/bin/sh" | awk '{print $NF}')
        _base=$(basename "$_target" 2>/dev/null)
        case "$_base" in
            mksh|ash) _shell_type="$_base" ;;
            busybox) _shell_type="ash" ;;
        esac
    else
        _shell_type="ash"
    fi
    case "$_shell_type" in
        mksh|ash|ksh) ;;
        *) echo "❌ Unsupported shell type: $_shell_type, please use mksh/ash/ksh"; exit 1 ;;
    esac

    CPU_ARCH=$(getprop ro.product.cpu.abi 2>/dev/null || uname -m)
    CPU_ARCH=$(echo "$CPU_ARCH" | tr '[:upper:]' '[:lower:]')
    case "$CPU_ARCH" in
        *arm*|*aarch64*) echo "Detected ARM architecture: $CPU_ARCH" ;;
        *) echo "❌ Unsupported CPU architecture: $CPU_ARCH"; exit 1 ;;
    esac

    _mtk_platform=$(getprop ro.mediatek.platform 2>/dev/null)
    _board_platform=$(getprop ro.board.platform 2>/dev/null)
    case "$_mtk_platform$_board_platform" in
        *[mM][tT]*|*[Mm][Tt]*) IS_MEDIATEK=1 ;;
    esac
}

print_disclaimer() {
    echo "————————————————————"
    echo "OnePlus Anti-Rollback Detector"
    echo "Authors: Jingyuxuan-Stillrain, Bartixxx"
    echo
    printf "%b\n" "${YELLOW}This detection method follows the MIT License. If anyone redistributes without crediting the original authors, please report to me.${NC}"
    echo ""
    printf "%b\n" "${YELLOW}Disclaimer:${NC}"
    printf "%b\n" "${YELLOW}This tool is only used to extract the xbl_config image and analyze the ARB status,${NC}"
    printf "%b\n" "${YELLOW}it does not modify system behavior, and it does not assume any risk of flashing.${NC}"
    echo ""
    printf "%b\n" "${YELLOW}If you agree to the detection, please wait;${NC}"
    printf "%b\n" "${YELLOW}If you disagree, press Ctrl+C to exit.${NC}"
    printf "%b\n" "${YELLOW}The program will start automatically in 7 seconds.${NC}"
    i=7
    while [ $i -gt 0 ]; do
        printf "%s… " "$i"
        sleep 1
        i=$((i - 1))
    done
    echo ""
    echo "————————————————————"
}

get_active_slot() {
    _slot=$(getprop ro.boot.slot_suffix 2>/dev/null)
    if [ -z "$_slot" ]; then
        _slot=$(getprop ro.boot.slot 2>/dev/null)
    fi
    case "$_slot" in
        *_a|a) echo "a" ;;
        *_b|b) echo "b" ;;
        *) echo "" ;;
    esac
}

find_partition_path() {
    _basename="$1"
    _slot_suffix="$2"
    _found=""

    for _base in $CANDIDATE_BASES; do
        for _path in $_base; do
            if [ -d "$_path" ]; then
                if [ -n "$_slot_suffix" ]; then
                    _candidate="$_path/${_basename}_${_slot_suffix}"
                    if [ -e "$_candidate" ]; then
                        echo "$_candidate"
                        return 0
                    fi
                    _candidate="$_path/${_basename}${_slot_suffix}"
                    if [ -e "$_candidate" ]; then
                        echo "$_candidate"
                        return 0
                    fi
                else
                    _candidate="$_path/${_basename}"
                    if [ -e "$_candidate" ]; then
                        echo "$_candidate"
                        return 0
                    fi
                fi
            fi
        done
    done

    _tmp_list="$WORK_DIR/find_part.tmp"
    su -c "find /dev/block -type f -name '*xbl_config*' 2>/dev/null > $_tmp_list"
    while read -r _file; do
        _fname=$(basename "$_file")
        _suffix=${_fname##xbl_config}
        if [ -z "$_slot_suffix" ] && [ -z "$_suffix" ]; then
            echo "$_file"
            rm -f "$_tmp_list"
            return 0
        fi
        if [ "$_slot_suffix" = "a" ] && { [ "$_suffix" = "_a" ] || [ "$_suffix" = "a" ]; }; then
            echo "$_file"
            rm -f "$_tmp_list"
            return 0
        fi
        if [ "$_slot_suffix" = "b" ] && { [ "$_suffix" = "_b" ] || [ "$_suffix" = "b" ]; }; then
            echo "$_file"
            rm -f "$_tmp_list"
            return 0
        fi
    done < "$_tmp_list"
    rm -f "$_tmp_list"
    return 1
}

select_partition_manually() {
    echo "Scanning all partitions containing xbl_config..." >&2
    _tmp_list="$WORK_DIR/partlist.tmp"
    su -c "find /dev/block -name '*xbl_config*' 2>/dev/null > $_tmp_list"
    _count=0
    while read -r _line; do
        _count=$((_count + 1))
    done < "$_tmp_list"
    if [ $_count -eq 0 ]; then
        echo "❌ No xbl_config partitions found" >&2
        rm -f "$_tmp_list"
        return 1
    fi
    echo "Found the following partitions:" >&2
    _i=1
    while read -r _line; do
        printf "  %d) %s\n" $_i "$_line" >&2
        _i=$((_i + 1))
    done < "$_tmp_list"
    printf "Please enter a number to select (1-%d): " $_count >&2
    read _choice
    case "$_choice" in
        ''|*[!0-9]*) echo "❌ Invalid input" >&2; rm -f "$_tmp_list"; return 1 ;;
        *)
            if [ $_choice -lt 1 ] || [ $_choice -gt $_count ]; then
                echo "❌ Number out of range" >&2; rm -f "$_tmp_list"; return 1
            fi
            _i=1
            while read -r _line; do
                if [ $_i -eq $_choice ]; then
                    echo "$_line"
                    rm -f "$_tmp_list"
                    return 0
                fi
                _i=$((_i + 1))
            done < "$_tmp_list"
            ;;
    esac
    rm -f "$_tmp_list"
    return 1
}

prepare_tools() {
    echo "Preparing detection tools..."
    cleanup
    su -c "mkdir -p \"$WORK_DIR\"" 2>/dev/null || {
        echo "❌ Unable to create directory $WORK_DIR"
        exit 1
    }

    _script_self="$0"
    _line=$(awk "/^${MARKER}$/{print NR; exit}" "$_script_self")
    if [ -z "$_line" ]; then
        echo "❌ Archive marker not found, script may be corrupted"
        exit 1
    fi

    _zip_path="$WORK_DIR/bin.zip"
    tail -n +$((_line + 1)) "$_script_self" | su -c "cat > \"$_zip_path\"" 2>/dev/null || {
        echo "❌ Failed to extract appended data"
        exit 1
    }

    if command -v sha256sum >/dev/null 2>&1; then
        _hash=$(su -c "sha256sum \"$_zip_path\"" | cut -d' ' -f1)
    elif command -v busybox >/dev/null 2>&1 && busybox sha256sum --help >/dev/null 2>&1; then
        _hash=$(su -c "busybox sha256sum \"$_zip_path\"" | cut -d' ' -f1)
    elif [ -n "$BUSYBOX_CMD" ] && "$BUSYBOX_CMD" sha256sum --help >/dev/null 2>&1; then
        _hash=$(su -c "$BUSYBOX_CMD sha256sum \"$_zip_path\"" | cut -d' ' -f1)
    elif command -v openssl >/dev/null 2>&1; then
        _hash=$(su -c "openssl dgst -sha256 \"$_zip_path\"" | cut -d' ' -f2)
    else
        echo "❌ No available SHA256 calculation tool found"
        exit 1
    fi

    if [ "$_hash" != "$EXPECTED_ZIP_SHA256" ]; then
        echo "❌ Archive hash verification failed"
        echo "Expected: $EXPECTED_ZIP_SHA256"
        echo "Actual: $_hash"
        exit 1
    fi
    echo "Hash verification passed."

    if command -v unzip >/dev/null 2>&1; then
        su -c "unzip -q -o \"$_zip_path\" -d \"$WORK_DIR\"" || {
            echo "❌ Failed to unzip bin.zip"
            exit 1
        }
    elif command -v busybox >/dev/null 2>&1 && busybox unzip --help >/dev/null 2>&1; then
        su -c "busybox unzip -q -o \"$_zip_path\" -d \"$WORK_DIR\"" || {
            echo "❌ Failed to unzip using busybox"
            exit 1
        }
    elif [ -n "$BUSYBOX_CMD" ] && "$BUSYBOX_CMD" unzip --help >/dev/null 2>&1; then
        su -c "$BUSYBOX_CMD unzip -q -o \"$_zip_path\" -d \"$WORK_DIR\"" || {
            echo "❌ Failed to unzip using alternate busybox"
            exit 1
        }
    else
        echo "❌ unzip command not found, cannot extract"
        exit 1
    fi

    su -c "rm -f \"$_zip_path\""

    case "$CPU_ARCH" in
        *aarch64*|*arm64*)
            _tool_zip="arb_inspector-aarch64-linux-android.zip"
            ;;
        *armv7*|*armeabi*|*arm*)
            _tool_zip="arb_inspector-armv7-linux-androideabi.zip"
            ;;
        *)
            echo "❌ Unrecognized ARM architecture variant: $CPU_ARCH"
            exit 1
            ;;
    esac

    if ! su -c "test -f \"$WORK_DIR/$_tool_zip\""; then
        echo "❌ $_tool_zip not found in bin.zip"
        exit 1
    fi

    if command -v unzip >/dev/null 2>&1; then
        su -c "unzip -q -o \"$WORK_DIR/$_tool_zip\" -d \"$WORK_DIR\"" || {
            echo "❌ Failed to unzip $_tool_zip"
            exit 1
        }
    elif command -v busybox >/dev/null 2>&1 && busybox unzip --help >/dev/null 2>&1; then
        su -c "busybox unzip -q -o \"$WORK_DIR/$_tool_zip\" -d \"$WORK_DIR\"" || {
            echo "❌ Failed to unzip $_tool_zip using busybox"
            exit 1
        }
    elif [ -n "$BUSYBOX_CMD" ] && "$BUSYBOX_CMD" unzip --help >/dev/null 2>&1; then
        su -c "$BUSYBOX_CMD unzip -q -o \"$WORK_DIR/$_tool_zip\" -d \"$WORK_DIR\"" || {
            echo "❌ Failed to unzip $_tool_zip using alternate busybox"
            exit 1
        }
    else
        echo "❌ unzip command not found, cannot extract tool package"
        exit 1
    fi

    su -c "rm -f \"$WORK_DIR\"/arb_inspector-*.zip"
    BIN_PATH="$WORK_DIR/arb_inspector"
    if ! su -c "test -f \"$BIN_PATH\""; then
        echo "❌ arb_inspector file not found after extraction"
        exit 1
    fi
    su -c "chmod 755 \"$BIN_PATH\"" 2>/dev/null || {
        echo "❌ Unable to set execute permission for arb_inspector"
        exit 1
    }
    echo "Tools ready."
}

extract_xbl_config() {
    _slot="$1"
    _manual_path="$2"
    if [ -n "$_manual_path" ]; then
        PARTITION_PATH="$_manual_path"
    else
        PARTITION_PATH=$(find_partition_path "xbl_config" "$_slot")
    fi

    if [ -z "$PARTITION_PATH" ]; then
        echo "❌ xbl_config partition not found"
        return 1
    fi

    _dst="$WORK_DIR/$OUTPUT_FILE"
    if ! su -c "cat '$PARTITION_PATH' > '$_dst'"; then
        echo "❌ Failed to read partition $PARTITION_PATH"
        return 1
    fi
    echo "xbl_config image extracted to $_dst"
    return 0
}

run_detection() {
    _img="$WORK_DIR/$OUTPUT_FILE"
    if ! su -c "test -f \"$_img\""; then
        echo "❌ Image file does not exist"
        exit 1
    fi

    BUILD_ID=$(getprop ro.build.display.id)
    echo "Device build ID: $BUILD_ID"
    echo "Current slot: $ACTIVE_SLOT"

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
    esac

    if [ $SAFE_DEVICE -eq 1 ]; then
        echo "----------------------------------------"
        echo "✅ $DEVICE_NAME series currently does not have ARB fuse mechanism"
        echo "----------------------------------------"
        su -c rm -f "$_img" >/dev/null 2>&1
        exit 0
    fi

    echo "Running detection..."
    echo "————————————————————"
    _output=$(su -c "$BIN_PATH \"$_img\"" 2>&1)
    _status=$?

    if [ $_status -ne 0 ] || [ -z "$_output" ]; then
        echo "❌ Detection failed, arb_inspector returned error"
        echo "$_output"
        exit 1
    fi

    echo "==============================="
    echo "ARB Detection Result:"
    echo "$_output" | grep -E "OEM Metadata|Anti-Rollback Version"
    _ver=$(echo "$_output" | awk -F': ' '/Anti-Rollback Version/ {print $2}')
    echo "==============================="
    if [ -n "$_ver" ]; then
        if [ "$_ver" -eq 0 ] 2>/dev/null; then
            printf "Anti-Rollback ${GREEN}Not Enabled${NC}\n"
            echo "MediaTek devices have hidden ARB, so this is not recommended as a reference!"
        elif [ "$_ver" -gt 0 ] 2>/dev/null; then
            printf "Anti-Rollback ${RED}Enabled${NC}, version: %s\n" "$_ver"
            echo "Do not flash an older version, otherwise it will brick!"
        else
            echo "Parsed version number is not a number: $_ver"
        fi
    else
        printf "${YELLOW}Unable to detect ARB status${NC}\n"
        echo "Full output log:"
        echo "$_output"
    fi
    echo "==============================="
}

main() {
    check_environment
    print_disclaimer

    ACTIVE_SLOT=$(get_active_slot)
    echo "Current active slot: ${ACTIVE_SLOT:-None}"

    prepare_tools

    if ! extract_xbl_config "$ACTIVE_SLOT"; then
        echo "Automatic partition identification failed. Manually select? (y/n)"
        read _ans
        case "$_ans" in
            [yY]|[yY][eE][sS])
                _manual=$(select_partition_manually)
                if [ -n "$_manual" ]; then
                    extract_xbl_config "" "$_manual" || exit 1
                else
                    exit 1
                fi
                ;;
            *)
                echo "User cancelled operation."
                exit 0
                ;;
        esac
    fi

    run_detection
    sync
}

trap cleanup EXIT
main
exit 0
__ARCHIVE_FOLLOWS__
