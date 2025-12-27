#!/bin/bash

# --- 配置参数 ---
PROXY_FWMARK=1
PROXY_ROUTE_TABLE=100
INTERFACE=$(ip -4 route show default | grep default | awk '{print $5}' | head -n 1)

# 颜色
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 读取模式
if [ -f "/etc/sing-box/mode.conf" ]; then
    MODE=$(grep "^MODE=" /etc/sing-box/mode.conf | cut -d'=' -f2)
else
    MODE=""
fi

# 清理 TProxy 残留
cleanup_tproxy() {
    echo -e "${CYAN}清理 TProxy 路由和规则...${NC}"
    # 清理 nftables 表
    nft list table inet sing-box >/dev/null 2>&1 && nft delete table inet sing-box
    
    # 清理路由策略
    while ip rule show | grep -q "lookup $PROXY_ROUTE_TABLE"; do
        ip rule del fwmark $PROXY_FWMARK lookup $PROXY_ROUTE_TABLE 2>/dev/null
    done
    
    # 清理路由表
    ip route del local default dev "$INTERFACE" table $PROXY_ROUTE_TABLE 2>/dev/null
}

if [ "$MODE" = "TUN" ]; then
    echo -e "${CYAN}正在配置 TUN 模式环境...${NC}"

    # 1. 彻底清理 TProxy 规则 (防止冲突)
    cleanup_tproxy

    # 2. 配置 TUN 专用防火墙 (可选)
    # 注意：TUN 模式通常由 sing-box 自身创建 tun0 接口并配置路由
    # 这里我们只需确保没有干扰规则。
    # 不要使用 flush ruleset！这会清除 SSH 访问规则！
    
    sudo mkdir -p /etc/sing-box/tun
    
    # 如果需要确保转发正常，可以单独开启
    sysctl -w net.ipv4.ip_forward=1 > /dev/null

    # 3. 保存状态
    # 仅在确实有改动时保存，TUN模式通常依赖 auto 路由，这里仅做清理即可
    echo -e "${GREEN}✓ TUN 模式环境准备就绪 (TProxy 规则已清理)。${NC}"
    
else
    echo -e "${YELLOW}当前非 TUN 模式，跳过配置。${NC}"
fi