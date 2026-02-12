#!/system/bin/sh

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
echo -e "一加 Anti-Rollback 检测程序"
echo -e "作者：静雨轩-Stillrain"
echo -e "${YELLOW}此检测方式由我首个公开发布，遵循 MIT License，若有直接搬运不标明原作者的，请向我反馈。${NC}"
echo ""
echo -e "${YELLOW}免责声明：${NC}"
echo -e "${YELLOW}本工具仅用于提取 xbl_config 镜像及分析 ARB 状态，${NC}"
echo -e "${YELLOW}不修改系统行为，也不承担刷机风险。${NC}"
echo ""
echo -e "${YELLOW}若您同意检测，请等待；${NC}"
echo -e "${YELLOW}若不同意，请退出此程序${NC}"
echo -e "${YELLOW}程序将在 7 秒后自动开始${NC}"
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

[ -z "$BIN" ] && BIN=$(find /storage/emulated/0 -type f -name arbscan \
    ! -path "/storage/emulated/0/DCIM/*" \
    ! -path "/storage/emulated/0/Pictures/*" \
    ! -path "/storage/emulated/0/Movies/*" \
    ! -path "/storage/emulated/0/Android/*" 2>/dev/null | head -n 1)

# 检查是否找到文件
if [ -z "$BIN" ]; then
    echo "未找到 local arbscan，正在从网络下载..."
    # 下载到当前目录并保留
    DL_PATH="$(pwd)/arbscan"
    URL="https://raw.githubusercontent.com/Bartixxx32/OnePlus-Anti-Rollback-Detector/main/arbscan"
    
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
        
        # 复制到 /data/local/tmp 以便执行
        # 我们保留当前目录下的下载文件供下次使用
        TMP_BIN="/data/local/tmp/arbscan"
        su -c "cp \"$BIN\" \"$TMP_BIN\"" || { echo "复制到工作目录时发生错误！"; exit 1; }
        BIN="$TMP_BIN"
    else
        echo "下载失败！"
        exit 1
    fi
else
    echo "找到的文件：$BIN"
fi

# 检查是否找到文件 (Above logic handles exit on failure, but keep safe check)
[ -z "$BIN" ] && { echo "ERR:BIN"; exit 1; }

# 提取镜像
IMAGE_PATH="/data/local/tmp/xbl_config${SLOT}.img"
echo "镜像提取中，请稍候..."
su -c "dd if=/dev/block/by-name/xbl_config${SLOT} of=${IMAGE_PATH} bs=4096" >/dev/null 2>&1
sleep 0.1
if [ $? -eq 0 ]; then
    echo "镜像提取成功"
else
    echo "提取镜像时发生错误，但继续执行脚本。"
fi

# 拷贝到 /data/local/tmp
TMP_BIN="/data/local/tmp/arbscan"
su -c "cp \"$BIN\" \"$TMP_BIN\"" || { echo "复制到工作目录时发生错误！"; exit 1; }
# 检查文件权限
su -c "chmod +x \"$TMP_BIN\"" || { echo "为脚本授权时发生错误！"; exit 1; }

# 提示用户镜像提取完成
echo "镜像提取完成，正在执行检测...请稍等"
echo "——————————————————"
# 输出 build 号
# 输出 build 号
BUILD_ID=$(getprop ro.build.display.id)
echo "设备 build 号：$BUILD_ID"
echo "当前槽位：$(echo "$SLOT" | tr -d '_')"
# 执行检测
FULL_OUTPUT=$(echo N | su -c "$TMP_BIN" "$IMAGE_PATH" 2>&1 | grep "ARB Index")
# 原版输出
echo "$FULL_OUTPUT"

# 提取数字
IDX=$(echo "$FULL_OUTPUT" | awk -F: '/ARB Index/{gsub(/ /,"");print $2}')


su -c rm -f "$IMAGE_PATH"

if [ "$IDX" = "0" ]; then
    echo -e "Anti-Rollback${GREEN}未启用${NC}"
    echo "天玑机型有隐藏ARB，所以不推荐参考！"
else
    echo -e "Anti-Rollback${RED}已启用${NC}"
    echo "请不要自行刷机降级，否则会变砖！"
fi