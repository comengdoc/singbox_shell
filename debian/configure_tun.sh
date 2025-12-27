#!/bin/bash

# =========================================================
#  Sing-box TUN 模式网络配置脚本 (自动网卡 + NAT双重保险)
# =========================================================

# --- 1. 自动获取物理网卡名称 ---
# 获取默认路由接口 (通常是 eth0, end0 等)
INTERFACE=$(ip -4 route show default | grep default | awk '{print $5}' | head -n 1)

if [ -z "$INTERFACE" ]; then
    echo "警告: 无法获取默认网卡接口，回退使用 eth0"
    INTERFACE="eth0"
fi

# --- 2. 核心网络设置 ---
# 开启 IP 转发 (作为网关必须开启)
sysctl -w net.ipv4.ip_forward=1 > /dev/null

# 确保配置持久化
if ! grep -q "net.ipv4.ip_forward=1" /etc/sysctl.conf; then
    echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf > /dev/null
fi

# --- 3. 配置 Nftables ---
sudo mkdir -p /etc/sing-box/tun

echo "正在应用防火墙规则 (接口: $INTERFACE)..."

# 生成规则文件
cat > /etc/sing-box/tun/nftables.conf <<EOF
# 定义 ipv4/ipv6 混合表
table inet filter {
    chain input { type filter hook input priority 0; policy accept; }
    chain forward { type filter hook forward priority 0; policy accept; }
    chain output { type filter hook output priority 0; policy accept; }
}

# 定义 NAT 表 (作为双重保险，处理 ICMP 和 直连流量)
table ip nat {
    chain postrouting {
        type nat hook postrouting priority 100; policy accept;
        # 自动识别的网卡进行伪装
        oifname "$INTERFACE" masquerade
    }
}
EOF

# --- 4. 应用规则 ---
# 使用 -f 加载文件，不会暴力清空 Sing-box 自己的规则
if nft -f /etc/sing-box/tun/nftables.conf; then
    echo -e "\033[0;32m✓ 网络配置已应用 (NAT: ON, IF: $INTERFACE)\033[0m"
else
    echo -e "\033[0;31m✗ 规则应用失败\033[0m"
    exit 1
fi