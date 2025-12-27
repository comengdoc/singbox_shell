#!/bin/bash

# --- 样式定义 ---
CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="/etc/sing-box/scripts"

# 检查服务状态
if ! systemctl is-active --quiet sing-box; then
    echo -e "${YELLOW}Sing-box 服务当前未运行。${NC}"
    # 即使服务没运行，可能防火墙还在，允许继续清理
else
    echo -e "${CYAN}正在停止 Sing-box 服务...${NC}"
    sudo systemctl stop sing-box
    
    if ! systemctl is-active --quiet sing-box; then
        echo -e "${GREEN}✓ 服务已停止。${NC}"
    else
        echo -e "${RED}✗ 服务停止失败，请检查日志。${NC}"
        exit 1
    fi
fi

# 防火墙清理逻辑
echo -e "\n${YELLOW}是否清理相关的防火墙规则 (Nftables/TProxy)?${NC}"
echo -e "清理规则可以让网络恢复直连状态。"
read -rp "确认清理? (y/n, 默认 y): " clean_choice
clean_choice=${clean_choice:-y}

if [[ "$clean_choice" =~ ^[Yy]$ ]]; then
    if [ -f "$SCRIPT_DIR/clean_nft.sh" ]; then
        bash "$SCRIPT_DIR/clean_nft.sh"
    else
        echo -e "${RED}错误: 找不到清理脚本 clean_nft.sh${NC}"
        # 紧急后备清理
        sudo nft delete table inet sing-box 2>/dev/null
    fi
else
    echo -e "${CYAN}已保留防火墙规则。${NC}"
fi