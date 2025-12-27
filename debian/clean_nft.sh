#!/bin/bash

# --- 样式定义 ---
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${CYAN}正在停止 Sing-box 服务...${NC}"
sudo systemctl stop sing-box

echo -e "${CYAN}正在清理 Sing-box 防火墙规则...${NC}"

# 1. 清理 Sing-box 专用表 (TProxy模式主要使用)
if nft list table inet sing-box >/dev/null 2>&1; then
    sudo nft delete table inet sing-box
    echo -e "已删除 table inet sing-box"
fi

# 2. 清理 TUN 模式下的 NAT 规则 (精准清理)
# 注意：我们不 flush ip nat 表，防止误删 Docker 规则
# 我们只删除特定的 masquerade 规则 (如果有必要)
# 但由于 nat 表通常比较复杂，且单纯保留 masquerade 规则对系统无害，
# 这里选择保留 ip nat 表，以最大程度保护 Docker 环境。

# 3. 清理路由策略 (ip rule/route)
# 这些是 TProxy 模式残留的，TUN 模式自动清理
PROXY_FWMARK=1
PROXY_ROUTE_TABLE=100

while ip rule show | grep -q "lookup $PROXY_ROUTE_TABLE"; do
    sudo ip rule del fwmark $PROXY_FWMARK lookup $PROXY_ROUTE_TABLE 2>/dev/null
done

# 尝试删除路由表 (可能报错如果不存在，忽略即可)
sudo ip route flush table $PROXY_ROUTE_TABLE 2>/dev/null

echo -e "${GREEN}✓ 服务已停止，相关规则已清理 (Docker 规则已保留)。${NC}"