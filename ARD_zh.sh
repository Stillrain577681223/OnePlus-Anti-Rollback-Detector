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
        echo " ❌错误：请先解压整个zip文件后再运行！"
        echo " 不要在压缩包内直接运行！"
        echo "============================================"
        exit 1
    fi

    command -v su >/dev/null 2>&1 || {
        echo "❌ 错误：未找到 su 命令，需要 root 权限"
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
        *) echo "❌ 不支持的 shell 类型：$_shell_type，请使用 mksh/ash/ksh"; exit 1 ;;
    esac

    CPU_ARCH=$(getprop ro.product.cpu.abi 2>/dev/null || uname -m)
    CPU_ARCH=$(echo "$CPU_ARCH" | tr '[:upper:]' '[:lower:]')
    case "$CPU_ARCH" in
        *arm*|*aarch64*) echo "检测到 ARM 架构: $CPU_ARCH" ;;
        *) echo "❌ 不支持的 CPU 架构：$CPU_ARCH"; exit 1 ;;
    esac

    _mtk_platform=$(getprop ro.mediatek.platform 2>/dev/null)
    _board_platform=$(getprop ro.board.platform 2>/dev/null)
    case "$_mtk_platform$_board_platform" in
        *[mM][tT]*|*[Mm][Tt]*) IS_MEDIATEK=1 ;;
    esac
}

print_disclaimer() {
    echo "————————————————————"
    echo "一加 Anti-Rollback 检测程序"
    echo "作者：静雨轩-Stillrain, Bartixxx"
    echo
    printf "%b\n" "${YELLOW}此检测方式遵循 MIT License，若有直接搬运不标明原作者的，请向我反馈。${NC}"
    echo ""
    printf "%b\n" "${YELLOW}免责声明：${NC}"
    printf "%b\n" "${YELLOW}本工具仅用于提取 xbl_config 镜像及分析 ARB 状态，${NC}"
    printf "%b\n" "${YELLOW}不修改系统行为，也不承担刷机风险。${NC}"
    echo ""
    printf "%b\n" "${YELLOW}若您同意检测，请等待；${NC}"
    printf "%b\n" "${YELLOW}若不同意，请按 Ctrl+C 退出。${NC}"
    printf "%b\n" "${YELLOW}程序将在 7 秒后自动开始${NC}"
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
    echo "正在扫描所有包含 xbl_config 的分区..." >&2
    _tmp_list="$WORK_DIR/partlist.tmp"
    su -c "find /dev/block -name '*xbl_config*' 2>/dev/null > $_tmp_list"
    _count=0
    while read -r _line; do
        _count=$((_count + 1))
    done < "$_tmp_list"
    if [ $_count -eq 0 ]; then
        echo "❌ 未找到任何 xbl_config 分区" >&2
        rm -f "$_tmp_list"
        return 1
    fi
    echo "找到以下分区：" >&2
    _i=1
    while read -r _line; do
        printf "  %d) %s\n" $_i "$_line" >&2
        _i=$((_i + 1))
    done < "$_tmp_list"
    printf "请输入数字选择 (1-%d): " $_count >&2
    read _choice
    case "$_choice" in
        ''|*[!0-9]*) echo "❌ 输入无效" >&2; rm -f "$_tmp_list"; return 1 ;;
        *)
            if [ $_choice -lt 1 ] || [ $_choice -gt $_count ]; then
                echo "❌ 数字超出范围" >&2; rm -f "$_tmp_list"; return 1
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
    echo "正在准备检测工具..."
    cleanup
    su -c "mkdir -p \"$WORK_DIR\"" 2>/dev/null || {
        echo "❌ 无法创建目录 $WORK_DIR"
        exit 1
    }

    _script_self="$0"
    _line=$(awk "/^${MARKER}$/{print NR; exit}" "$_script_self")
    if [ -z "$_line" ]; then
        echo "❌ 未找到归档标记，脚本可能已损坏"
        exit 1
    fi

    _zip_path="$WORK_DIR/bin.zip"
    tail -n +$((_line + 1)) "$_script_self" | su -c "cat > \"$_zip_path\"" 2>/dev/null || {
        echo "❌ 提取附加数据失败"
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
        echo "❌ 找不到可用的 SHA256 计算工具"
        exit 1
    fi

    if [ "$_hash" != "$EXPECTED_ZIP_SHA256" ]; then
        echo "❌ 归档哈希校验失败"
        echo "期望: $EXPECTED_ZIP_SHA256"
        echo "实际: $_hash"
        exit 1
    fi
    echo "哈希校验通过。"

    if command -v unzip >/dev/null 2>&1; then
        su -c "unzip -q -o \"$_zip_path\" -d \"$WORK_DIR\"" || {
            echo "❌ 解压 bin.zip 失败"
            exit 1
        }
    elif command -v busybox >/dev/null 2>&1 && busybox unzip --help >/dev/null 2>&1; then
        su -c "busybox unzip -q -o \"$_zip_path\" -d \"$WORK_DIR\"" || {
            echo "❌ 使用 busybox 解压失败"
            exit 1
        }
    elif [ -n "$BUSYBOX_CMD" ] && "$BUSYBOX_CMD" unzip --help >/dev/null 2>&1; then
        su -c "$BUSYBOX_CMD unzip -q -o \"$_zip_path\" -d \"$WORK_DIR\"" || {
            echo "❌ 使用备用 busybox 解压失败"
            exit 1
        }
    else
        echo "❌ 未找到 unzip 命令，无法解压"
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
            echo "❌ 无法识别的 ARM 架构变体: $CPU_ARCH"
            exit 1
            ;;
    esac

    if ! su -c "test -f \"$WORK_DIR/$_tool_zip\""; then
        echo "❌ 在 bin.zip 中未找到 $_tool_zip"
        exit 1
    fi

    if command -v unzip >/dev/null 2>&1; then
        su -c "unzip -q -o \"$WORK_DIR/$_tool_zip\" -d \"$WORK_DIR\"" || {
            echo "❌ 解压 $_tool_zip 失败"
            exit 1
        }
    elif command -v busybox >/dev/null 2>&1 && busybox unzip --help >/dev/null 2>&1; then
        su -c "busybox unzip -q -o \"$WORK_DIR/$_tool_zip\" -d \"$WORK_DIR\"" || {
            echo "❌ 使用 busybox 解压 $_tool_zip 失败"
            exit 1
        }
    elif [ -n "$BUSYBOX_CMD" ] && "$BUSYBOX_CMD" unzip --help >/dev/null 2>&1; then
        su -c "$BUSYBOX_CMD unzip -q -o \"$WORK_DIR/$_tool_zip\" -d \"$WORK_DIR\"" || {
            echo "❌ 使用备用 busybox 解压 $_tool_zip 失败"
            exit 1
        }
    else
        echo "❌ 未找到 unzip 命令，无法解压工具包"
        exit 1
    fi

    su -c "rm -f \"$WORK_DIR\"/arb_inspector-*.zip"
    BIN_PATH="$WORK_DIR/arb_inspector"
    if ! su -c "test -f \"$BIN_PATH\""; then
        echo "❌ 解压后未找到 arb_inspector 文件"
        exit 1
    fi
    su -c "chmod 755 \"$BIN_PATH\"" 2>/dev/null || {
        echo "❌ 无法设置 arb_inspector 执行权限"
        exit 1
    }
    echo "工具准备完成。"
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
        echo "❌ 找不到 xbl_config 分区"
        return 1
    fi

    _dst="$WORK_DIR/$OUTPUT_FILE"
    if ! su -c "cat '$PARTITION_PATH' > '$_dst'"; then
        echo "❌ 读取分区 $PARTITION_PATH 失败"
        return 1
    fi
    echo "已提取 xbl_config 镜像到 $_dst"
    return 0
}

run_detection() {
    _img="$WORK_DIR/$OUTPUT_FILE"
    if ! su -c "test -f \"$_img\""; then
        echo "❌ 镜像文件不存在"
        exit 1
    fi

    BUILD_ID=$(getprop ro.build.display.id)
    echo "设备 build 号：$BUILD_ID"
    echo "当前槽位: $ACTIVE_SLOT"

    SAFE_DEVICE=0
    case "$BUILD_ID" in
        *PLK110*|*CPH2747*|*CPH2745*)
            DEVICE_NAME="一加 15"
            SAFE_DEVICE=1
            ;;
        *PLQ110*)
            DEVICE_NAME="一加 Ace6"
            SAFE_DEVICE=1
            ;;
        *PLR110*)
            DEVICE_NAME="一加 Ace6T"
            SAFE_DEVICE=1
            ;;
    esac

    if [ $SAFE_DEVICE -eq 1 ]; then
        echo "----------------------------------------"
        echo "✅ $DEVICE_NAME 系列目前没有引进ARB熔断机制"
        echo "----------------------------------------"
        su -c rm -f "$_img" >/dev/null 2>&1
        exit 0
    fi

    echo "正在执行检测..."
    echo "————————————————————"
    _output=$(su -c "$BIN_PATH \"$_img\"" 2>&1)
    _status=$?

    if [ $_status -ne 0 ] || [ -z "$_output" ]; then
        echo "❌ 检测失败，arb_inspector 返回错误"
        echo "$_output"
        exit 1
    fi

    echo "==============================="
    echo "ARB 检测结果："
    echo "$_output" | grep -E "OEM Metadata|Anti-Rollback Version"
    _ver=$(echo "$_output" | awk -F': ' '/Anti-Rollback Version/ {print $2}')
    echo "==============================="
    if [ -n "$_ver" ]; then
        if [ "$_ver" -eq 0 ] 2>/dev/null; then
            printf "Anti-Rollback ${GREEN}未启用${NC}\n"
            echo "天玑机型有隐藏ARB，所以不推荐作为参考！"
        elif [ "$_ver" -gt 0 ] 2>/dev/null; then
            printf "Anti-Rollback ${RED}已启用${NC}，版本: %s\n" "$_ver"
            echo "请不要自行刷机降级，否则会变砖！"
        else
            echo "解析到的版本号非数字: $_ver"
        fi
    else
        printf "${YELLOW}无法检测到 ARB 状态${NC}\n"
        echo "完整输出日志："
        echo "$_output"
    fi
    echo "==============================="
}

main() {
    check_environment
    print_disclaimer

    ACTIVE_SLOT=$(get_active_slot)
    echo "当前活动槽位: ${ACTIVE_SLOT:-无}"

    prepare_tools

    if ! extract_xbl_config "$ACTIVE_SLOT"; then
        echo "自动识别分区失败，是否手动选择？(y/n)"
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
                echo "用户取消操作。"
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
