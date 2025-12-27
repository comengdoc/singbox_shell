#!/bin/bash

# =================配置区域=================
# 仓库配置 (统一指向你的仓库)
REPO_USER="comengdoc"
REPO_NAME="singbox_shell"
REPO_BRANCH="main"
PROXY_URL="https://ghfast.top/"

# 构造下载地址
BASE_URL="${PROXY_URL}https://raw.githubusercontent.com/${REPO_USER}/${REPO_NAME}/refs/heads/${REPO_BRANCH}/debian"
MAIN_SCRIPT_URL="${BASE_URL}/menu.sh"

# 安装目录
SCRIPT_DIR="/etc/sing-box/scripts"

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m' 
# =========================================

# 1. 系统检查
check_sys() {
    if [[ "$(uname -s)" != "Linux" ]]; then
        echo -e "${RED}错误：本脚本仅支持 Linux 系统。${NC}"
        exit 1
    fi

    if ! grep -qi 'debian\|ubuntu\|armbian' /etc/os-release; then
        echo -e "${RED}错误：本脚本仅支持 Debian / Ubuntu / Armbian 发行版。${NC}"
        exit 1
    fi
}

# 2. 依赖检查与安装
install_depend() {
    local dependencies=("wget" "curl" "sudo" "nftables")
    local need_apt_update=false

    for dep in "${dependencies[@]}"; do
        if ! command -v "$dep" &> /dev/null && [ "$dep" != "nftables" ]; then
            echo -e "${YELLOW}正在安装依赖: $dep ...${NC}"
            if [ "$need_apt_update" = false ]; then
                sudo apt-get update -y
                need_apt_update=true
            fi
            sudo apt-get install -y "$dep"
        elif [ "$dep" == "nftables" ] && ! nft --version &> /dev/null; then
             echo -e "${YELLOW}正在安装依赖: $dep ...${NC}"
             if [ "$need_apt_update" = false ]; then
                sudo apt-get update -y
                need_apt_update=true
            fi
            sudo apt-get install -y nftables
        fi
    done
}

# 3. 准备目录
prepare_dir() {
    if [ ! -d "$SCRIPT_DIR" ]; then
        sudo mkdir -p "$SCRIPT_DIR"
        sudo chown "$(whoami)":"$(whoami)" "$SCRIPT_DIR"
    fi
}

# 4. 主逻辑
main() {
    clear
    echo -e "${CYAN}====================================================${NC}"
    echo -e "${CYAN}      Sing-box Shell 安装引导器 (sbshell)${NC}"
    echo -e "${CYAN}====================================================${NC}"
    
    check_sys
    install_depend
    prepare_dir

    # 智能判断：如果 menu.sh 已存在
    if [ -f "$SCRIPT_DIR/menu.sh" ]; then
        echo -e "${GREEN}检测到本地已安装脚本。${NC}"
        echo -e " [1] 直接启动 (默认)"
        echo -e " [2] 强制更新并重装"
        read -rp "请选择 (1/2): " choice
        
        if [[ "$choice" == "2" ]]; then
            echo -e "${YELLOW}正在强制更新主脚本...${NC}"
            rm -f "$SCRIPT_DIR/menu.sh"
        else
            echo -e "${GREEN}正在启动...${NC}"
            chmod +x "$SCRIPT_DIR/menu.sh"
            bash "$SCRIPT_DIR/menu.sh"
            exit 0
        fi
    fi

    # 下载流程
    echo -e "${GREEN}正在从 GitHub 下载主脚本...${NC}"
    echo -e "${CYAN}源地址: ${MAIN_SCRIPT_URL}${NC}"
    
    wget -q -O "$SCRIPT_DIR/menu.sh" "$MAIN_SCRIPT_URL"

    if [ ! -f "$SCRIPT_DIR/menu.sh" ] || [ ! -s "$SCRIPT_DIR/menu.sh" ]; then
        echo -e "${RED}下载失败！请检查网络或代理设置。${NC}"
        echo -e "${YELLOW}尝试手动访问: $MAIN_SCRIPT_URL${NC}"
        exit 1
    fi

    echo -e "${GREEN}下载成功！${NC}"
    echo -e "${YELLOW}提示: 安装更新 singbox 尽量使用代理环境，运行 singbox 切记关闭代理!${NC}"
    
    chmod +x "$SCRIPT_DIR/menu.sh"
    bash "$SCRIPT_DIR/menu.sh"
}

main