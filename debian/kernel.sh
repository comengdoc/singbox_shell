#!/bin/bash

# 本脚本用于添加 XanMod 内核仓库，获取必要的 GPG 密钥，
# 检测 CPU 指令集，安装合适的 XanMod 内核版本，并重启系统。

set -euo pipefail

# 定义颜色以便提示更醒目
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 错误处理函数
error() {
    echo -e "${RED}错误: $1${NC}" >&2
    exit 1
}

# 确保以 root 用户运行脚本
if [ "$(id -u)" -ne 0 ]; then
    error "必须以 root 用户运行此脚本。"
fi

# ==========================================
# 核心修改：架构兼容性安全检查
# ==========================================
ARCH=$(dpkg --print-architecture)
echo "正在检查系统架构..."

if [[ "$ARCH" != "amd64" ]]; then
    echo -e "${RED}======================================================${NC}"
    echo -e "${RED}  严重警告：不支持的系统架构 ($ARCH)  ${NC}"
    echo -e "${RED}======================================================${NC}"
    echo -e "${YELLOW}XanMod 内核官方仅支持 x86_64 (amd64) 架构的设备。${NC}"
    echo -e "${YELLOW}检测到您正在 ARM 架构设备（如树莓派、NanoPi、软路由盒子）上运行。${NC}"
    echo -e "${YELLOW}在此设备上强制安装 x86 内核会导致：${NC}"
    echo -e "  1. 系统无法引导 (变砖)"
    echo -e "  2. 必须拆机取出 TF 卡/硬盘重刷系统"
    echo -e ""
    echo -e "${RED}为了您的系统安全，脚本已自动终止。${NC}"
    echo -e "Armbian 请直接使用 armbian-config 或官方源更新内核。"
    exit 1
else
    echo -e "架构检查通过：$ARCH (支持 XanMod)"
fi
# ==========================================

# 更新软件包列表
echo "正在更新软件包列表..."
apt update || error "更新软件包列表失败。"

# 安装必要工具（gpg 和 curl）
for cmd in gpg curl; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "正在安装 $cmd..."
        apt install "$cmd" -y || error "安装 $cmd 失败。"
    fi
done

# 确保密钥环目录存在
KEYRING_DIR="/etc/apt/keyrings"
mkdir -p "$KEYRING_DIR"

# 定义 XanMod 的 GPG 密钥 URL 和密钥环文件路径
XANMOD_KEY_URL="https://dl.xanmod.org/archive.key"
XANMOD_KEYRING="$KEYRING_DIR/xanmod-archive-keyring.gpg"

# 方法一：使用 gpg 参数抑制提示
echo "使用 gpg 参数添加 XanMod GPG 密钥..."
if ! curl -fsSL "$XANMOD_KEY_URL" | gpg --batch --yes --dearmor -o "$XANMOD_KEYRING"; then
    echo "使用 gpg 参数添加 GPG 密钥失败，尝试方法二..."

    # 方法二：写入前先删除已有密钥环文件
    rm -f "$XANMOD_KEYRING"
    if ! curl -fsSL "$XANMOD_KEY_URL" | gpg --dearmor -o "$XANMOD_KEYRING"; then
        error "使用两种方法均无法从 $XANMOD_KEY_URL 添加 GPG 密钥。"
    fi
fi

# 定义仓库列表文件和仓库条目
REPO_LIST="/etc/apt/sources.list.d/xanmod-release.list"
REPO_ENTRY="deb [signed-by=$XANMOD_KEYRING] http://deb.xanmod.org releases main"

# 检查仓库是否已添加
if [ ! -f "$REPO_LIST" ] || ! grep -Fxq "$REPO_ENTRY" "$REPO_LIST"; then
    echo "正在添加 XanMod 仓库..."
    echo "$REPO_ENTRY" | tee "$REPO_LIST" >/dev/null
else
    echo "XanMod 仓库已存在。"
fi

# 更新软件包列表以包含新仓库
echo "正在更新软件包列表（包括 XanMod 仓库）..."
apt update || error "添加仓库后更新软件包列表失败。"

# 检测 CPU 指令集
echo "正在检测 CPU 指令集..."
cpu_flags=$(grep -o -w -E 'lm|cmov|cx8|fpu|fxsr|mmx|syscall|sse2|cx16|lahf|popcnt|sse4_1|sse4_2|ssse3|avx|avx2|bmi1|bmi2|f16c|fma|abm|movbe|xsave|avx512f|avx512bw|avx512cd|avx512dq|avx512vl' /proc/cpuinfo | sort -u | tr '\n' ' ')
echo "检测到的 CPU 标志: $cpu_flags"

# 检查是否包含所有所需指令集的函数
has_flags() {
    local flags="$1"
    for flag in $flags; do
        [[ "$cpu_flags" =~ $flag ]] || return 1
    done
    return 0
}

# 根据指令集判断 CPU 级别
# 注意：以下指令集判断仅适用于 x86 架构
if has_flags "avx512f avx512bw avx512cd avx512dq avx512vl"; then
    level=4
elif has_flags "avx avx2 bmi1 bmi2 f16c fma abm movbe xsave"; then
    level=3
elif has_flags "cx16 lahf popcnt sse4_1 sse4_2 ssse3"; then
    level=2
elif has_flags "lm cmov cx8 fpu fxsr mmx syscall sse2"; then
    level=1
else
    error "无法根据 CPU 指令集确定合适的 XanMod 内核版本。"
fi

echo "检测到的 CPU 级别: $level"

# 根据 CPU 级别设置内核包名称
case "$level" in
    1)
        kernel_package="linux-xanmod-lts-x64v1"
        ;;
    2)
        kernel_package="linux-xanmod-lts-x64v2"
        ;;
    3)
        kernel_package="linux-xanmod-lts-x64v3"
        ;;
    4)
        kernel_package="linux-xanmod-lts-x64v4"
        ;;
    *)
        error "无效的 CPU 级别: $level"
        ;;
esac

# 安装合适的 XanMod 内核
echo "正在安装 $kernel_package..."
apt install "$kernel_package" -y || error "安装 $kernel_package 失败。"

# 提示系统重启
echo -e "${YELLOW}内核安装完成！${NC}"
echo "系统将在 10 秒后重启，按 Ctrl+C 可取消。"
for i in {10..1}; do
    echo "$i..."
    sleep 1
done
echo "现在重启系统！"
reboot