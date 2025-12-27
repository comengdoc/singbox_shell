#!/bin/bash

# --- 样式定义 ---
CYAN='\033[0;36m'
GREEN='\033[0;32m'
MAGENTA='\033[0;35m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="/etc/sing-box/scripts"

# 1. 环境检测 (防止在已有代理的环境下启动导致死循环)
check_env() {
    echo -e "${CYAN}正在检查网络环境...${NC}"
    # 使用 curl 检测是否能直连 Google (以此判断是否处于全局代理下)
    # 注意：如果本来就没网，这步也会失败。所以仅作为提示。
    HTTP_CODE=$(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 3 "https://www.google.com")

    if [ "$HTTP_CODE" -eq 200 ]; then
        echo -e "${YELLOW}警告: 能够直接访问 Google (HTTP 200)。${NC}"
        echo -e "如果是国内环境，这可能意味着你正在通过另一个代理 (如软路由上级) 上网。"
        echo -e "在代理环境下启动 sing-box 可能会导致流量回环。"
        read -rp "是否仍要继续启动? (y/n): " force_start
        if [[ ! "$force_start" =~ ^[Yy]$ ]]; then
            exit 0
        fi
    fi
}

# 2. 防火墙应用逻辑
apply_firewall() {
    # 检查是否配置了 Systemd 自动托管
    if [ -f "/etc/systemd/system/sing-box.service.d/override.conf" ]; then
        echo -e "${GREEN}检测到 Systemd 托管配置，防火墙规则将随服务自动启动。${NC}"
    else
        # 手动应用
        if [ -f "/etc/sing-box/mode.conf" ]; then
            MODE=$(grep "^MODE=" /etc/sing-box/mode.conf | cut -d'=' -f2)
            echo -e "${CYAN}正在应用防火墙规则 ($MODE)...${NC}"
            if [ "$MODE" = "TProxy" ]; then
                bash "$SCRIPT_DIR/configure_tproxy.sh"
            elif [ "$MODE" = "TUN" ]; then
                bash "$SCRIPT_DIR/configure_tun.sh"
            fi
        fi
    fi
}

# 3. 主启动逻辑
main() {
    check_env
    
    echo -e "${CYAN}正在启动 Sing-box...${NC}"
    sudo systemctl restart sing-box

    if systemctl is-active --quiet sing-box; then
        echo -e "${GREEN}✓ Sing-box 启动成功${NC}"
        
        # 应用防火墙 (如果需要手动)
        apply_firewall
        
        # 显示模式
        if nft list table inet sing-box >/dev/null 2>&1; then
             echo -e "当前模式: ${MAGENTA}已加载防火墙规则${NC}"
        else
             echo -e "当前模式: ${YELLOW}未检测到活动防火墙规则 (可能是纯客户端模式)${NC}"
        fi
    else
        echo -e "${RED}✗ 启动失败！日志如下:${NC}"
        sudo journalctl -u sing-box -n 10 --output cat
    fi
}

main