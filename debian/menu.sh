#!/bin/bash

#################################################
# 描述: Debian/Ubuntu/Armbian 官方sing-box 全自动脚本
# 维护: comengdoc
# 版本: 3.2.0 (Added Uninstall)
#################################################

# --- 1. 全局配置 ---
# 仓库信息 (必须与 sbshell 保持一致)
REPO_USER="comengdoc"
REPO_NAME="singbox_shell"
PROXY_URL="https://ghfast.top/"
BASE_URL="${PROXY_URL}https://raw.githubusercontent.com/${REPO_USER}/${REPO_NAME}/refs/heads/main/debian"

SCRIPT_DIR="/etc/sing-box/scripts"
INITIALIZED_FILE="$SCRIPT_DIR/.initialized"
ROLE_FILE="$SCRIPT_DIR/.role"
ROLE="" 

# 颜色定义
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
WHITE='\033[1;37m'
BOLD='\033[1m'
NC='\033[0m'

# 脚本清单 (已包含 uninstall.sh)
SCRIPTS=(
    "menu.sh" "install_singbox.sh" "check_update.sh" "update_scripts.sh" "update_ui.sh"
    "manual_input.sh" "manual_update.sh" "auto_update.sh" "switch_mode.sh" "configure_tproxy.sh" "configure_tun.sh"
    "update_config.sh" "setup.sh" "ufw.sh" "uninstall.sh"
    "start_singbox.sh" "stop_singbox.sh" "manage_autostart.sh" "check_config.sh"
    "check_environment.sh" "set_network.sh" "clean_nft.sh" "kernel.sh" "optimize.sh" "set_defaults.sh" "delaytest.sh" "commands.sh"
)

# --- 2. 辅助函数 ---

# 获取服务状态 (UI优化)
get_service_status() {
    if systemctl is-active --quiet sing-box; then
        echo -e "${GREEN}● 运行中${NC}"
    else
        echo -e "${RED}● 已停止${NC}"
    fi
}

# 获取开机自启状态
get_enable_status() {
    if systemctl is-enabled --quiet sing-box 2>/dev/null; then
        echo -e "${GREEN}是${NC}"
    else
        echo -e "${RED}否${NC}"
    fi
}

# 脚本执行器
run_script() {
    local message="$1"
    local script_name="$2"
    local quiet_mode="$3"
    
    echo -e "${CYAN}> ${message}...${NC}"
    if [ "$quiet_mode" == "--quiet" ]; then
        bash "$SCRIPT_DIR/$script_name" >/dev/null
    else
        bash "$SCRIPT_DIR/$script_name"
    fi

    if [ $? -ne 0 ]; then
        echo -e "${RED}✗ ${message}失败！${NC}"
        return 1
    else
        if [ "$quiet_mode" == "--quiet" ]; then
            echo -e "${GREEN}✓ ${message}成功。${NC}"
        fi
        return 0
    fi
}

run_systemctl() {
    local message="$1"
    local action="$2"
    echo -e "${CYAN}> ${message}...${NC}"
    if sudo systemctl "$action" sing-box >/dev/null 2>&1; then
        echo -e "${GREEN}✓ 成功${NC}"; return 0
    else
        echo -e "${RED}✗ 失败${NC}"; return 1
    fi
}

# --- 3. 下载与更新 ---

download_script() {
    local script="$1"
    wget -q -O "$SCRIPT_DIR/$script" "$BASE_URL/$script"
}

parallel_download_scripts() {
    echo -e "${CYAN}正在同步最新脚本...${NC}"
    local pids=()
    for script in "${SCRIPTS[@]}"; do
        download_script "$script" &
        pids+=("$!")
    done
    for pid in "${pids[@]}"; do wait "$pid"; done
    echo -e "${GREEN}脚本同步完成。${NC}"
}

check_and_download_scripts() {
    local missing=0
    for script in "${SCRIPTS[@]}"; do
        [ ! -f "$SCRIPT_DIR/$script" ] && missing=1
    done
    [ $missing -eq 1 ] && parallel_download_scripts
}

# --- 4. 初始化 ---

setup_alias() {
    # 同时支持 bash 和 zsh
    for rc in ~/.bashrc ~/.zshrc; do
        if [ -f "$rc" ] && ! grep -q "alias sb=" "$rc"; then
            echo -e "\n# sing-box 快捷方式\nalias sb='bash $SCRIPT_DIR/menu.sh'" >> "$rc"
            echo -e "${GREEN}已添加快捷命令 'sb' 到 $(basename "$rc")。${NC}"
        fi
    done
    if [ ! -f /usr/local/bin/sb ]; then
        echo -e '#!/bin/bash\nbash /etc/sing-box/scripts/menu.sh "$@"' | sudo tee /usr/local/bin/sb >/dev/null
        sudo chmod +x /usr/local/bin/sb
    fi
}

run_initialization() {
    echo -e "${CYAN}请选择运行角色: [1] 客户端 [2] 服务端${NC}"
    read -rp "输入数字: " role_choice
    case $role_choice in
        1) ROLE="client" ;;
        2) ROLE="server" ;;
        *) ROLE="client" ;;
    esac
    echo "$ROLE" > "$ROLE_FILE"
    
    echo -e "${YELLOW}即将开始初始化 ($ROLE)...${NC}"
    read -rp "按回车开始 (输入 skip 仅下载脚本): " init_choice
    
    if [[ "$init_choice" =~ ^[Ss]kip$ ]]; then
        parallel_download_scripts
    else
        parallel_download_scripts
        if [ "$ROLE" = "server" ]; then
             run_script "配置防火墙" "ufw.sh" "--auto"
             run_script "安装 Sing-box" "install_singbox.sh" --quiet
             run_script "更新配置" "update_config.sh"
             run_systemctl "启动服务" "start"
        else
             run_script "环境检查" "check_environment.sh" --quiet
             run_script "安装 Sing-box" "install_singbox.sh" --quiet
             run_script "配置模式" "switch_mode.sh"
             run_script "导入订阅" "manual_input.sh"
             run_script "启动服务" "start_singbox.sh" --quiet
        fi
        touch "$INITIALIZED_FILE"
    fi
}

# --- 5. 菜单 UI ---

show_header() {
    clear
    local status=$(get_service_status)
    local enable=$(get_enable_status)
    local ip=$(curl -s --max-time 2 ifconfig.me || echo "获取失败")
    
    echo -e "${CYAN}====================================================${NC}"
    echo -e "           ${BOLD}Sing-box 管理面板${NC} ${YELLOW}[$ROLE]${NC}"
    echo -e "${CYAN}====================================================${NC}"
    echo -e " 状态: $status      自启: $enable"
    echo -e " IP:   $ip"
    echo -e "${CYAN}----------------------------------------------------${NC}"
}

show_client_menu() {
    show_header
    echo -e "${BOLD}${LIGHT_BLUE}[ 配置管理 ]${NC}"
    echo -e "  1. 切换模式 (TProxy/TUN)    2. 手动更新订阅"
    echo -e "  3. 自动更新设置             4. 修改默认参数"
    
    echo -e "\n${BOLD}${LIGHT_PURPLE}[ 服务控制 ]${NC}"
    echo -e "  5. 启动服务                 6. 停止服务"
    echo -e "  7. 管理开机自启             8. 查看实时日志" 
    
    echo -e "\n${BOLD}${YELLOW}[ 维护更新 ]${NC}"
    echo -e "  9. 更新内核 (Sing-box)      10. 更新脚本"
    echo -e "  11. 更新面板 (Yacd/Meta)    ${RED}99. 彻底卸载${NC}"
    
    echo -e "\n${BOLD}${WHITE}[ 系统工具 ]${NC}"
    echo -e "  12. 网络设置                13. 常用命令速查"
    echo -e "  14. 更换 XanMod 内核        15. 系统/网络优化"
    echo -e "${CYAN}====================================================${NC}"
    echo -e "${GREEN} 0. 退出${NC}"
    echo -n " 请输入选项: "
}

show_server_menu() {
    show_header
    echo -e "${BOLD}${LIGHT_PURPLE}[ 服务控制 ]${NC}"
    echo -e "  1. 启动服务                 2. 停止服务"
    echo -e "  3. 重启服务                 4. 开机自启开关"
    echo -e "  5. 查看实时日志"
    
    echo -e "\n${BOLD}${YELLOW}[ 配置维护 ]${NC}"
    echo -e "  6. 更新配置文件             7. 更新内核 (Sing-box)"
    echo -e "  8. 更新本脚本               9. SSL 证书申请"
    echo -e "  ${RED}99. 彻底卸载${NC}"
    
    echo -e "\n${BOLD}${WHITE}[ 系统优化 ]${NC}"
    echo -e "  10. 更换 XanMod 内核        11. 网络拥塞优化"
    echo -e "  12. 防火墙配置 (UFW)"
    echo -e "${CYAN}====================================================${NC}"
    echo -e "${GREEN} 0. 退出${NC}"
    echo -n " 请输入选项: "
}

# --- 6. 主逻辑 ---

main() {
    sudo mkdir -p "$SCRIPT_DIR"
    sudo chown "$(whoami)":"$(whoami)" "$SCRIPT_DIR"
    cd "$SCRIPT_DIR" || exit 1

    # 初始化检查
    if [ ! -f "$INITIALIZED_FILE" ]; then
        run_initialization
    fi
    
    # 加载角色
    if [ -f "$ROLE_FILE" ]; then
        ROLE=$(cat "$ROLE_FILE")
    else
        ROLE="client" # 默认回退
    fi

    # 检查脚本完整性
    check_and_download_scripts
    setup_alias

    # 菜单循环
    while true; do
        if [ "$ROLE" = "server" ]; then
            show_server_menu
            read -r choice
            case $choice in
                1) run_systemctl "启动服务" "start" ;;
                2) run_systemctl "停止服务" "stop" ;;
                3) run_systemctl "重启服务" "restart" ;;
                4) run_systemctl "设置自启" "enable" ;;
                5) sudo journalctl -u sing-box --output cat -f ;;
                6) run_script "更新配置" "update_config.sh" ;;
                7) run_script "更新Sing-box" "check_update.sh" ;;
                8) run_script "更新脚本" "update_scripts.sh" ;;
                9) run_script "证书申请" "setup.sh" ;;
                10) run_script "更换内核" "kernel.sh" ;;
                11) run_script "网络优化" "optimize.sh" ;;
                12) run_script "配置防火墙" "ufw.sh" ;;
                99) run_script "彻底卸载" "uninstall.sh" ; exit 0 ;;
                0) exit 0 ;;
                *) echo -e "${RED}无效输入${NC}"; sleep 1 ;;
            esac
        else
            show_client_menu
            read -r choice
            case $choice in
                1) run_script "切换模式" "switch_mode.sh"; run_script "导入订阅" "manual_input.sh"; run_script "启动服务" "start_singbox.sh" --quiet ;;
                2) run_script "更新配置" "manual_update.sh" ;;
                3) run_script "自动更新" "auto_update.sh" ;;
                4) run_script "默认参数" "set_defaults.sh" ;;
                5) run_script "启动服务" "start_singbox.sh" --quiet ;;
                6) run_script "停止服务" "stop_singbox.sh" --quiet ;;
                7) run_script "自启管理" "manage_autostart.sh" ;;
                8) sudo journalctl -u sing-box --output cat -f ;;
                9) run_script "更新Sing-box" "check_update.sh" ;;
                10) run_script "更新脚本" "update_scripts.sh" ;;
                11) run_script "更新面板" "update_ui.sh" ;;
                12) run_script "网络设置" "set_network.sh" ;;
                13) run_script "命令速查" "commands.sh" ;;
                14) run_script "更换内核" "kernel.sh" ;;
                15) run_script "网络优化" "optimize.sh" ;;
                99) run_script "彻底卸载" "uninstall.sh" ; exit 0 ;;
                0) exit 0 ;;
                *) echo -e "${RED}无效输入${NC}"; sleep 1 ;;
            esac
        fi
        echo -e "\n${CYAN}按回车键返回菜单...${NC}"
        read -r
    done
}

main "$@"