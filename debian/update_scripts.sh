#!/bin/bash

# --- 样式定义 ---
CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# --- 配置 ---
SCRIPT_DIR="/etc/sing-box/scripts"
TEMP_DIR="/tmp/sing-box_update"
REPO_USER="comengdoc"
REPO_NAME="singbox_shell"
REPO_BRANCH="main"
PROXY_URL="https://ghfast.top/"
BASE_URL="${PROXY_URL}https://raw.githubusercontent.com/${REPO_USER}/${REPO_NAME}/${REPO_BRANCH}/debian"

# 脚本清单 (确保包含所有新脚本，包括 uninstall.sh)
SCRIPTS=(
    "menu.sh" "sbshell.sh" 
    "install_singbox.sh" "check_environment.sh" "check_update.sh" 
    "start_singbox.sh" "stop_singbox.sh" "switch_mode.sh"
    "configure_tproxy.sh" "configure_tun.sh" "clean_nft.sh"
    "update_scripts.sh" "update_config.sh" "update_ui.sh"
    "manual_input.sh" "manual_update.sh" "auto_update.sh"
    "manage_autostart.sh" "set_defaults.sh" "set_network.sh"
    "check_config.sh" "setup.sh" "ufw.sh" "kernel.sh" "optimize.sh" 
    "delaytest.sh" "commands.sh" "uninstall.sh"
)

# 确保目录
mkdir -p "$SCRIPT_DIR" "$TEMP_DIR"

# --- 函数 ---

download_file() {
    local filename="$1"
    local url="${BASE_URL}/${filename}"
    
    # 使用临时文件，防止网络中断导致文件损坏
    if wget -q -O "${TEMP_DIR}/${filename}" "$url"; then
        return 0
    else
        return 1
    fi
}

check_version() {
    echo -e "${CYAN}正在检查版本信息...${NC}"
    # 下载远程 menu.sh 进行比对
    if ! download_file "menu.sh"; then
        echo -e "${RED}无法连接更新服务器，请检查网络。${NC}"
        return 1
    fi

    local local_ver=$(grep '^# 版本:' "$SCRIPT_DIR/menu.sh" 2>/dev/null | awk '{print $3}')
    local remote_ver=$(grep '^# 版本:' "${TEMP_DIR}/menu.sh" | awk '{print $3}')

    echo -e "本地版本: ${YELLOW}${local_ver:-未知}${NC}"
    echo -e "远程版本: ${GREEN}${remote_ver:-未知}${NC}"

    if [ "$local_ver" == "$remote_ver" ] && [ -n "$remote_ver" ]; then
        echo -e "${GREEN}当前已是最新版本。${NC}"
        return 0 # 无需更新
    else
        return 2 # 需要更新
    fi
}

do_update() {
    echo -e "${CYAN}开始下载脚本...${NC}"
    local fail_count=0
    
    for script in "${SCRIPTS[@]}"; do
        echo -n "同步 $script ... "
        if download_file "$script"; then
            echo -e "${GREEN}OK${NC}"
        else
            echo -e "${RED}失败${NC}"
            ((fail_count++))
        fi
    done

    if [ $fail_count -eq 0 ]; then
        echo -e "${CYAN}正在应用更新...${NC}"
        # 批量移动并赋权
        cp -f "${TEMP_DIR}"/*.sh "$SCRIPT_DIR/"
        chmod +x "$SCRIPT_DIR"/*.sh
        # 清理
        rm -rf "$TEMP_DIR"
        echo -e "${GREEN}✓ 所有脚本更新完成。${NC}"
    else
        echo -e "${RED}更新未完全成功，有 $fail_count 个文件下载失败。${NC}"
        echo -e "${YELLOW}未应用部分更新以保证完整性。${NC}"
    fi
}

do_reset() {
    echo -e "${RED}警告: 这将删除所有脚本并重新下载，配置文件将保留。${NC}"
    read -rp "确认重置? (y/n): " confirm
    [[ ! "$confirm" =~ ^[Yy]$ ]] && return

    rm -rf "$SCRIPT_DIR"/*.sh
    do_update
}

# --- 主逻辑 ---

echo -e "${CYAN}=== 脚本更新管理器 ===${NC}"
check_version
update_needed=$?

if [ $update_needed -eq 1 ]; then
    exit 1
elif [ $update_needed -eq 0 ]; then
    read -rp "已是最新版，是否强制覆盖更新? (y/n): " force
    [[ ! "$force" =~ ^[Yy]$ ]] && exit 0
fi

echo "1. 执行更新 (推荐)"
echo "2. 强制重置 (修复脚本缺失/损坏)"
echo "0. 取消"
read -rp "请选择: " choice

case $choice in
    1) do_update ;;
    2) do_reset ;;
    *) echo "取消"; exit 0 ;;
esac