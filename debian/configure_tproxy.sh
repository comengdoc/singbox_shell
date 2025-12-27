#!/bin/bash

# --- 配置参数 ---
TPROXY_PORT=7895
ROUTING_MARK=666
PROXY_FWMARK=1
PROXY_ROUTE_TABLE=100

# 自动获取默认网卡接口 (更健壮的写法)
INTERFACE=$(ip -4 route show default | grep default | awk '{print $5}' | head -n 1)

# IP 集合定义
ReservedIP4='{ 127.0.0.0/8, 10.0.0.0/8, 100.64.0.0/10, 169.254.0.0/16, 172.16.0.0/12, 192.0.0.0/24, 192.0.2.0/24, 198.51.100.0/24, 192.88.99.0/24, 192.168.0.0/16, 203.0.113.0/24, 224.0.0.0/4, 240.0.0.0/4, 255.255.255.255/32 }'
CustomBypassIP='{ 192.168.0.0/16, 10.0.0.0/8 }'

# 颜色
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 读取模式 (兼容没有 -P 参数的 grep)
if [ -f "/etc/sing-box/mode.conf" ]; then
    MODE=$(grep "^MODE=" /etc/sing-box/mode.conf | cut -d'=' -f2)
else
    MODE=""
fi

# 辅助函数：清理旧规则
clear_singbox_rules() {
    echo "清理旧的 TProxy 规则..."
    nft list table inet sing-box >/dev/null 2>&1 && nft delete table inet sing-box
    ip rule del fwmark $PROXY_FWMARK lookup $PROXY_ROUTE_TABLE 2>/dev/null
    ip route del local default dev "${INTERFACE}" table $PROXY_ROUTE_TABLE 2>/dev/null
}

if [ "$MODE" = "TProxy" ]; then
    echo -e "${CYAN}正在应用 TProxy 防火墙规则 (接口: $INTERFACE)...${NC}"
    
    # 1. 配置 IP 路由
    # 确保路由表存在
    if ! ip route show table "$PROXY_ROUTE_TABLE" | grep -q default; then
        echo "添加本地路由..."
        ip route add local default dev "$INTERFACE" table "$PROXY_ROUTE_TABLE"
    fi

    # 确保策略路由存在
    if ! ip rule show | grep -q "lookup $PROXY_ROUTE_TABLE"; then
        echo "添加策略路由规则..."
        ip rule add fwmark $PROXY_FWMARK lookup $PROXY_ROUTE_TABLE
    fi
    
    # 开启转发
    sysctl -w net.ipv4.ip_forward=1 > /dev/null

    # 2. 配置 Nftables
    mkdir -p /etc/sing-box/nft
    cat > /etc/sing-box/nft/nftables.conf <<EOF
table inet sing-box {
    set RESERVED_IPSET {
        type ipv4_addr; flags interval; auto-merge;
        elements = $ReservedIP4
    }

    chain prerouting_tproxy {
        type filter hook prerouting priority mangle; policy accept;
        
        # 排除
        ip daddr $CustomBypassIP accept
        fib daddr type local accept
        ip daddr @RESERVED_IPSET accept

        # DNS 劫持
        meta l4proto { tcp, udp } th dport 53 tproxy to :$TPROXY_PORT accept

        # 防止回环死循环
        fib daddr type local meta l4proto { tcp, udp } th dport $TPROXY_PORT reject with icmpx type host-unreachable
        
        # 现有连接保持
        meta l4proto tcp socket transparent 1 meta mark set $PROXY_FWMARK accept

        # 通用 TProxy 劫持
        meta l4proto { tcp, udp } tproxy to :$TPROXY_PORT meta mark set $PROXY_FWMARK
    }

    chain output_tproxy {
        type route hook output priority mangle; policy accept;
        
        # 排除
        meta oifname "lo" accept
        meta mark $ROUTING_MARK accept
        udp dport { netbios-ns, netbios-dgm, netbios-ssn } accept
        ip daddr $CustomBypassIP accept
        fib daddr type local accept
        ip daddr @RESERVED_IPSET accept

        # DNS 标记
        meta l4proto { tcp, udp } th dport 53 meta mark set $PROXY_FWMARK

        # 通用标记
        meta l4proto { tcp, udp } meta mark set $PROXY_FWMARK
    }
}
EOF

    # 应用规则
    if nft -f /etc/sing-box/nft/nftables.conf; then
        echo -e "${GREEN}✓ TProxy 规则已生效。${NC}"
        # 保存规则 (注意：这会覆盖系统默认规则文件，如果是多服务环境请谨慎)
        nft list ruleset > /etc/nftables.conf
    else
        echo -e "${RED}✗ 规则应用失败！${NC}"
        exit 1
    fi

else
    echo -e "${YELLOW}当前非 TProxy 模式，跳过防火墙配置。${NC}"
fi