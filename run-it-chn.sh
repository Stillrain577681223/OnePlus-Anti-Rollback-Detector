#!/system/bin/sh

CURRENT_DIR=$(pwd)
EXPECTED_SHA256="75b088c4f311045b656ec38f4665c121added6f041bb9e551429ecca6b8b7fb0"
# 禁止在 Android/data 目录 或 路径含 zip 时运行
echo "$CURRENT_DIR" | grep -qE "^/storage/emulated/0/Android/data/|zip"
if [ $? -eq 0 ]; then
    echo "============================================"
    echo " ❌错误：请先解压整个zip文件后再运行！"
    echo " 不要在压缩包内直接运行！"
    echo "============================================"
    exit 1
fi

su -c "dd if=/dev/zero of=/sdcard/__test__ bs=1 count=1" >/dev/null 2>&1
if [ $? -eq 0 ]; then
  ENV="system"
  su -c "rm -f /sdcard/__test__" >/dev/null 2>&1
else
  ENV="mt_ext"
fi
if [ "$ENV" = "mt_ext" ]; then
  echo "❌ 当前环境：MT 扩展包（不支持运行）"
  echo "请切换到 MT 系统环境运行"
  exit 1
fi

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
echo "————————————————————"
echo "一加 Anti-Rollback 检测程序 ver1.5"
echo "作者：静雨轩-Stillrain"
echo "由Github@Bartixxx提供部分技术支持和代码改进"
echo "欢迎各位前往Bartixxx的ARB查询网站"
echo "https://oneplusantiroll.netlify.app"
echo
echo "${YELLOW}此检测方式由我首次公开发布，遵循 MIT License，若有直接搬运不标明原作者的，请向我反馈。${NC}"
echo ""
echo "${YELLOW}免责声明：${NC}"
echo "${YELLOW}本工具仅用于提取 xbl_config 镜像及分析 ARB 状态，${NC}"
echo "${YELLOW}不修改系统行为，也不承担刷机风险。${NC}"
echo ""
echo "${YELLOW}若您同意检测，请等待；${NC}"
echo "${YELLOW}若不同意，请退出此程序${NC}"
echo "${YELLOW}程序若没有输出结果直接退出，请重新运行一次，若还没有结果，请前往酷安反馈${NC}"
echo "${YELLOW}程序将在 7 秒后自动开始${NC}"
for i in 7 6 5 4 3 2 1; do
  echo -n "$i… "
  sleep 1
done
echo ""
echo "————————————————————"
# 当前槽位
SLOT=$(getprop ro.boot.slot_suffix 2>/dev/null)
PART="/dev/block/by-name/xbl_config${SLOT}"

if ! su -c cat "$PART" > /dev/null 2>&1; then
    echo "没有该分区！"
    exit 1
fi

# 提示用户正在查找 arbscan
echo "正在搜索 arbscan 位置，请稍候..."
# 找到 arbscan
# 获取脚本所在目录
SCRIPT_DIR=$(dirname "$0")

BIN=$(find "$SCRIPT_DIR" -type f -name arbscan 2>/dev/null | head -n 1)

[ -z "$BIN" ] && BIN=$(find /storage/emulated/0/Download -type f -name arbscan 2>/dev/null | head -n 1)

[ -z "$BIN" ] && BIN=$(find /storage/emulated/0 \
-type d \( -name "DCIM" -o -name "Pictures" -o -name "Movies" -o -name "Android" \) -prune -o \
-type f -name "arbscan" -print 2>/dev/null | head -n 1)

    
NEED_COPY=1
# 检查是否找到文件，感谢Github@Bartixxx提供代码
#———————————————————————
if [ -z "$BIN" ]; then
    echo "未找到 local arbscan，正在从国内源Gitee下载..."
    DL_PATH="$(pwd)/arbscan"
    URL="https://gitee.com/Stillrain001/OnePlus-Anti-Rollback-Detector/raw/main/arbscan"

    if curl --help >/dev/null 2>&1; then
        curl -sL "$URL" -o "$DL_PATH"
    elif wget --help >/dev/null 2>&1; then
        wget -q "$URL" -O "$DL_PATH"
    else
        echo "下载失败 (缺少 curl/wget)。"
        exit 1
    fi


    FILE_SHA256=$(sha256sum "$DL_PATH" 2>/dev/null | awk '{print $1}')
    SHA256_INVALID=0

    if [ "$FILE_SHA256" != "$EXPECTED_SHA256" ]; then
        echo "文件校验不通过"
        echo ""
        rm -f "$DL_PATH"
        SHA256_INVALID=1
    else
        echo "文件校验成功"
    fi

    # 大小不对 → 强制算下载失败 → 走 Github
    if [ $SHA256_INVALID -eq 1 ] || [ ! -f "$DL_PATH" ]; then
        echo "下载失败！"
        echo "尝试使用国外源Github下载"
        URL="https://raw.githubusercontent.com/Stillrain577681223/OnePlus-Anti-Rollback-Detector/main/arbscan"

        if curl --help >/dev/null 2>&1; then
            curl -sL "$URL" -o "$DL_PATH"
        elif wget --help >/dev/null 2>&1; then
            wget -q "$URL" -O "$DL_PATH"
        else
            echo "下载失败 (缺少 curl/wget)。"
            exit 1
        fi

        if [ -f "$DL_PATH" ]; then
            BIN="$DL_PATH"
            chmod +x "$BIN"
            echo "下载成功。"
            FILE_SHA256=$(sha256sum "$BIN" 2>/dev/null | awk '{print $1}')

            if [ "$FILE_SHA256" != "$EXPECTED_SHA256" ]; then
                echo "文件校验不通过"
                echo ""
                rm -f "$DL_PATH"
                exit 1
            fi
        else
            echo "下载失败！"
            exit 1
        fi
    else
        BIN="$DL_PATH"
        chmod +x "$BIN"
        echo "下载成功。"
    fi

    # 复制到 /data/local/tmp
    if [ $NEED_COPY -eq 1 ] && [ -n "$BIN" ]; then
        TMP_BIN="/data/local/tmp/arbscan"
        su -c "cp \"$BIN\" \"$TMP_BIN\"" || { echo "复制到工作目录时发生错误！"; exit 1; }
        BIN="$TMP_BIN"
        NEED_COPY=0
    fi

else
    echo "找到的文件：$BIN"

    FILE_SHA256=$(sha256sum "$BIN" 2>/dev/null | awk '{print $1}')

    if [ "$FILE_SHA256" != "$EXPECTED_SHA256" ]; then
        echo "文件校验不通过"
        rm -f "$BIN"
        BIN=""
    fi
fi

# 本地文件坏了 → 重新走下载逻辑
if [ -z "$BIN" ]; then
    echo "本地文件无效，重新下载..."
    DL_PATH="$(pwd)/arbscan"
    URL="https://gitee.com/Stillrain001/OnePlus-Anti-Rollback-Detector/blob/main/arbscan"

    if curl --help >/dev/null 2>&1; then
        curl -sL "$URL" -o "$DL_PATH"
    elif wget --help >/dev/null 2>&1; then
        wget -q "$URL" -O "$DL_PATH"
    else
        echo "下载失败 (缺少 curl/wget)。"
        exit 1
    fi

    FILE_SHA256=$(sha256sum "$DL_PATH" 2>/dev/null | awk '{print $1}')
    SHA256_INVALID=0

    if [ "$FILE_SHA256" != "$EXPECTED_SHA256" ]; then
        echo "文件校验不通过"
        echo ""
        rm -f "$DL_PATH"
        SHA256_INVALID=1
    fi

    # 大小不对 → 强制算下载失败 → 走 Github
    if [ $SHA256_INVALID -eq 1 ] || [ ! -f "$DL_PATH" ]; then
        echo "下载失败！"
        echo "尝试使用国外源Github下载"
        URL="https://raw.githubusercontent.com/Stillrain577681223/OnePlus-Anti-Rollback-Detector/main/arbscan"

        if curl --help >/dev/null 2>&1; then
            curl -sL "$URL" -o "$DL_PATH"
        elif wget --help >/dev/null 2>&1; then
            wget -q "$URL" -O "$DL_PATH"
        else
            echo "下载失败 (缺少 curl/wget)。"
            exit 1
        fi

        if [ -f "$DL_PATH" ]; then
            BIN="$DL_PATH"
            chmod +x "$BIN"
            echo "下载成功。"
            FILE_SHA256=$(sha256sum "$BIN" 2>/dev/null | awk '{print $1}')

            if [ "$FILE_SHA256" != "$EXPECTED_SHA256" ]; then
                echo "文件校验不通过"
                echo ""
                rm -f "$DL_PATH"
                exit 1
            fi
        else
            echo "下载失败！"
            exit 1
        fi
    else
        BIN="$DL_PATH"
        chmod +x "$BIN"
        echo "下载成功。"
    fi

    # 复制到 /data/local/tmp
    if [ $NEED_COPY -eq 1 ] && [ -n "$BIN" ]; then
        TMP_BIN="/data/local/tmp/arbscan"
        su -c "cp \"$BIN\" \"$TMP_BIN\"" || { echo "复制到工作目录时发生错误！"; exit 1; }
        BIN="$TMP_BIN"
        NEED_COPY=0
    fi
fi

# 复制到 /data/local/tmp
if [ $NEED_COPY -eq 1 ] && [ -n "$BIN" ]; then
    TMP_BIN="/data/local/tmp/arbscan"
    su -c "cp \"$BIN\" \"$TMP_BIN\"" || { echo "复制到工作目录时发生错误！"; exit 1; }
    BIN="$TMP_BIN"
    NEED_COPY=0
fi

# 提取镜像
IMAGE_PATH="/data/local/tmp/xbl_config${SLOT}.img"
echo "镜像提取中，请稍候..."
su -c "dd if=/dev/block/by-name/xbl_config${SLOT} of=${IMAGE_PATH} bs=4096" >/dev/null 2>&1

if [ $? -eq 0 ]; then
    echo "镜像提取成功"
else
    echo "提取镜像时发生错误，但继续执行脚本。"
fi

# 拷贝到 /data/local/tmp
TMP_BIN="/data/local/tmp/arbscan"
if [ $NEED_COPY -eq 1 ]; then
  if [ "$BIN" != "$TMP_BIN" ]; then
    su -c "cp \"$BIN\" \"$TMP_BIN\"" || { echo "复制到工作目录时发生错误！"; exit 1; }
    NEED_COPY=0
  fi
fi
# 检查文件权限
su -c "chmod +x \"$TMP_BIN\"" || { echo "为脚本授权时发生错误！"; exit 1; }

# 提示用户镜像提取完成
echo "镜像提取完成，正在执行检测...请稍等"
echo "——————————————————"
# 输出 build 号
BUILD_ID=$(getprop ro.build.display.id)
echo "设备 build 号：$BUILD_ID"
echo "当前槽位: ${SLOT}"

# 机型匹配：安全机型直接提示并正常退出
DEVICE_NAME="设备"
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
  *)
    DEVICE_NAME=""
    SAFE_DEVICE=0
    ;;
esac

# ==============================
# 安全机型：正常退出，不报错！
# ==============================
if [ $SAFE_DEVICE -eq 1 ]; then
  echo "----------------------------------------"
  echo "✅ ${DEVICE_NAME} 系列目前没有引进ARB熔断机制"
  echo "----------------------------------------"
  su -c rm -f "$IMAGE_PATH" 2>/dev/null
fi

# ==============================
# 下面只有非安全机型才会运行
# ==============================
echo "正在执行检测..."

# 执行检测
FULL_OUTPUT=$(echo N | su -c "$TMP_BIN" "$IMAGE_PATH" 2>&1)

# 如果完全没有输出，直接报错退出
if [ -z "$FULL_OUTPUT" ]; then
    echo "❌ 检测失败：arbscan 未返回任何信息"
    echo "您的设备环境可能不支持此工具，请将压缩包解压后重新尝试"
    su -c rm -f "$IMAGE_PATH" 2>/dev/null
    exit 1
fi

# 输出结果
echo "$FULL_OUTPUT" | grep "ARB Index"

# 提取索引
IDX=$(echo "$FULL_OUTPUT" | grep "ARB Index" | tr -d ' ' | awk -F: '/ARBIndex/{print $2}')

su -c rm -f "$IMAGE_PATH" 2>/dev/null

if [ -n "$IDX" ]; then
    if [ "$IDX" = "0" ]; then
        echo -e "Anti-Rollback\033[0;32m未启用\033[0m"
        echo "天玑机型有隐藏ARB，所以不推荐作为参考！"
    else
        echo -e "Anti-Rollback\033[0;31m已启用\033[0m"
        echo -e "请不要自行刷机降级，否则会变砖！"
    fi
else
    echo -e "\033[1;33m无法检测到 ARB 状态\033[0m"
    echo -e "ARB Index 未返回任何内容，请检查 arbscan 文件是否正常。"
fi
sync
