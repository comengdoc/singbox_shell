#!/bin/bash

# --- 样式定义 ---
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

# 1. 架构检查 (最重要的一步)
ARCH=$(dpkg --print-architecture)

if [[ "$ARCH" != "amd64" ]]; then
    clear
    echo -e "${RED}######################################################${NC}"
    echo -e "${RED}#                严重警告 (Critical Warning)         #${NC}"
    echo -e "${RED}######################################################${NC}"
    echo -e "${YELLOW}检测到当前系统架构为: $ARCH${NC}"
    echo -e "${YELLOW}XanMod 内核仅支持 x86_64 (amd64) 架构的 PC 或服务器。${NC}"
    echo -e ""
    echo -e "您似乎正在使用 ARM 设备 (如 NanoPi, Raspberry Pi, 软路由盒子)。"
    echo -e "在此设备上强制安装 x86 内核将导致：${RED}系统无法启动 (变砖)${NC}。"
    echo -e ""
    echo -e "对于 Armbian 用户，请使用 ${GREEN}armbian-config${NC} 工具来管理内核。"
    echo -e "${RED}脚本已强制终止以保护您的系统。${NC}"
    exit 1
fi

# 下面是 x86 用户的逻辑 (只有 amd64 会执行到这里)
if [ "$(id -u)" -ne 0 ]; then
    echo "请使用 sudo 运行此脚本。"
    exit 1
fi

echo -e "${GREEN}架构检查通过 ($ARCH)。准备安装 XanMod 内核...${NC}"

# 安装依赖
sudo apt-get update
sudo apt-get install -y gpg curl

# 添加 GPG (优化版)
KEYRING="/etc/apt/keyrings/xanmod-archive-keyring.gpg"
mkdir -p /etc/apt/keyrings
rm -f "$KEYRING" # 清理旧的
curl -fsSL https://dl.xanmod.org/archive.key | gpg --dearmor -o "$KEYRING"

# 添加源
echo "deb [signed-by=$KEYRING] http://deb.xanmod.org releases main" | tee /etc/apt/sources.list.d/xanmod-release.list > /dev/null

# 更新并检测 CPU
sudo apt-get update
echo -e "${YELLOW}正在检测 CPU 指令集以选择最佳版本...${NC}"

# 简化的 CPU 级别检测逻辑 (利用官方脚本逻辑)
level=1
flags=$(cat /proc/cpuinfo)
if echo "$flags" | grep -q "avx512f"; then level=4;
elif echo "$flags" | grep -q "avx2"; then level=3;
elif echo "$flags" | grep -q "sse4_2"; then level=2; 
fi

PACKAGE="linux-xanmod-lts-x64v$level"
echo -e "检测到的 CPU 级别: v$level -> 对应包名: ${GREEN}$PACKAGE${NC}"

read -rp "确认安装 $PACKAGE ? (y/n): " confirm
if [[ "$confirm" =~ ^[Yy]$ ]]; then
    sudo apt-get install -y "$PACKAGE"
    echo -e "${GREEN}内核安装完成！${NC}"
    
    read -rp "需要重启系统以生效。是否立即重启? (y/n): " reboot_now
    if [[ "$reboot_now" =~ ^[Yy]$ ]]; then
        reboot
    fi
else
    echo "操作取消。"
fi