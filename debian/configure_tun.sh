#!/bin/bash

# =========================================================
#  Sing-box TUN 模式网络配置脚本 (修复局域网网关断网问题)
# =========================================================

# --- 1. 自动获取物理网卡名称 ---
# 获取默认路由接口 (通常是 eth0, end0 等)
INTERFACE=$(ip -4 route show default | grep default | awk '{print $5}' | head -n 1)

if [ -z "$INTERFACE" ]; then
    echo "错误: 无法获取默认网卡接口，尝试默认使用 eth0"
    INTERFACE="eth0"
fi

# --- 2. 核心网络设置 ---
# 开启 IP 转发 (作为网关必须开启)
echo "正在开启 IP 转发..."
sysctl -w net.ipv4.ip_forward=1 > /dev/null

# 确保配置持久化 (防止重启失效)
if ! grep -q "net.ipv4.ip_forward=1" /etc/sysctl.conf; then
    echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf > /dev/null
fi

# --- 3. 配置 Nftables 防火墙规则 ---
# 确保目录存在
sudo mkdir -p /etc/sing-box/tun

echo "正在应用防火墙规则 (Interface: $INTERFACE)..."

# 生成规则文件
cat > /etc/sing-box/tun/nftables.conf <<EOF
# 清空规则，确保环境纯净 (防止旧规则冲突)
flush ruleset

# 1. 基础过滤表 (Filter)
# 默认策略设为 accept，防止将自己锁在外面
table inet filter {
    chain input { 
        type filter hook input priority 0; policy accept; 
    }
    chain forward { 
        type filter hook forward priority 0; policy accept; 
    }
    chain output { 
        type filter hook output priority 0; policy accept; 
    }
}

# 2. NAT 表 (关键修复!)
# 为局域网流量做源地址伪装 (Masquerade)，确保回程流量能正确返回
table ip nat {
    chain postrouting {
        type nat hook postrouting priority 100; policy accept;
        oifname "$INTERFACE" masquerade
    }
}
EOF

# --- 4. 应用规则 ---
if nft -f /etc/sing-box/tun/nftables.conf; then
    echo -e "\033[0;32m✓ 防火墙规则应用成功 (NAT: 开启)\033[0m"
    
    # 保存规则到系统默认位置 (可选，视系统而定)
    # nft list ruleset > /etc/nftables.conf 2>/dev/null
else
    echo -e "\033[0;31m✗ 规则应用失败，请检查 nftables 服务\033[0m"
    exit 1
fi