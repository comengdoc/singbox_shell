#!/bin/bash

CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${CYAN}正在更新软件源信息...${NC}"
sudo apt-get update -qq

if ! command -v sing-box &> /dev/null; then
    echo -e "${RED}错误: 未检测到 sing-box，请先安装。${NC}"
    exit 1
fi

# 获取版本信息
current_version=$(sing-box version | grep 'sing-box version' | awk '{print $3}')
stable_version=$(apt-cache policy sing-box | grep Candidate | awk '{print $2}')
# 如果没有 Candidate，尝试获取 Installed 或第一行
[ -z "$stable_version" ] && stable_version="未知(未配置官方源?)"

# 检查是否存在 beta 源
beta_version=$(apt-cache policy sing-box-beta 2>/dev/null | grep Candidate | awk '{print $2}')
[ -z "$beta_version" ] && beta_version="未检测到测试版源"

echo -e "${CYAN}------------------------------${NC}"
echo -e "当前版本: ${GREEN}$current_version${NC}"
echo -e "最新稳定: ${YELLOW}$stable_version${NC}"
echo -e "最新测试: ${YELLOW}$beta_version${NC}"
echo -e "${CYAN}------------------------------${NC}"

echo "1. 切换/更新到 稳定版 (Stable)"
echo "2. 切换/更新到 测试版 (Beta)"
echo "0. 取消"
read -rp "请选择: " choice

# 准备临时目录
WORKDIR="/tmp/singbox_update"
mkdir -p "$WORKDIR"
rm -f "$WORKDIR"/*.deb

case $choice in
    1)
        echo -e "${CYAN}正在准备安装 稳定版...${NC}"
        cd "$WORKDIR" || exit
        
        # 卸载 beta 防止冲突
        if dpkg -l | grep -q sing-box-beta; then
            sudo apt-get remove --auto-remove sing-box-beta -y
        fi
        
        apt-get download sing-box
        if ls sing-box_*.deb 1> /dev/null 2>&1; then
            sudo dpkg -i sing-box_*.deb
            echo -e "${GREEN}更新完成！${NC}"
        else
            echo -e "${RED}下载失败，请检查网络。${NC}"
        fi
        ;;
    2)
        echo -e "${CYAN}正在准备安装 测试版...${NC}"
        cd "$WORKDIR" || exit

        # 卸载 stable 防止冲突
        if dpkg -l | grep -q "sing-box " | grep -v "sing-box-beta"; then
            sudo apt-get remove --auto-remove sing-box -y
        fi
        
        apt-get download sing-box-beta
        if ls sing-box-beta_*.deb 1> /dev/null 2>&1; then
            sudo dpkg -i sing-box-beta_*.deb
            echo -e "${GREEN}更新完成！${NC}"
        else
            echo -e "${RED}下载失败，请检查网络或确认是否添加了 beta 源。${NC}"
        fi
        ;;
    *)
        echo "操作已取消"
        ;;
esac

# 清理
rm -rf "$WORKDIR"