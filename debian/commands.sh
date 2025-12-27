#!/bin/bash

# 颜色定义
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# 脚本路径
SCRIPT_DIR="/etc/sing-box/scripts"

function view_firewall_rules() {
    echo -e "${YELLOW}查看当前 Nftables 规则...${NC}"
    sudo nft list ruleset
    read -rp "按回车键返回..."
}

function view_logs() {
    echo -e "${YELLOW}显示服务日志 (最后 50 行)...${NC}"
    sudo journalctl -u sing-box -n 50 --output cat -e
    read -rp "按回车键返回..."
}

function live_logs() {
    echo -e "${YELLOW}正在监听实时日志 (Ctrl+C 退出)...${NC}"
    sudo journalctl -u sing-box -f --output=cat
}

function check_config() {
    bash "$SCRIPT_DIR/check_config.sh"
    read -rp "按回车键返回..."
}

function run_delaytest() {
    bash "$SCRIPT_DIR/delaytest.sh"
    read -rp "按回车键返回..."
}

function fix_permissions() {
    echo -e "${YELLOW}正在修复权限与服务配置...${NC}"
    # 直接复用安装脚本中的逻辑，保持单一来源
    # 强制重新运行安装脚本中的配置部分
    bash "$SCRIPT_DIR/install_singbox.sh"
    read -rp "按回车键返回..."
}

function show_submenu() {
    clear
    echo -e "${CYAN}=========== 常用工具箱 ===========${NC}"
    echo -e "${MAGENTA} 1. 查看防火墙规则 (Nftables)${NC}"
    echo -e "${MAGENTA} 2. 查看历史日志${NC}"
    echo -e "${MAGENTA} 3. 查看实时日志${NC}"
    echo -e "${MAGENTA} 4. 检查配置文件语法${NC}"
    echo -e "${MAGENTA} 5. 真实网络延迟测试${NC}"
    echo -e "${MAGENTA} 6. 修复权限与服务配置 (Fix)${NC}"
    echo -e "${CYAN}================================${NC}"
    echo -e "${GREEN} 0. 返回主菜单${NC}"
}

while true; do
    show_submenu
    read -rp "请选择操作: " choice
    case $choice in
        1) view_firewall_rules ;;
        2) view_logs ;;
        3) live_logs ;;
        4) check_config ;;
        5) run_delaytest ;;
        6) fix_permissions ;;
        0) break ;;
        *) echo -e "${RED}无效输入${NC}"; sleep 1 ;;
    esac
done