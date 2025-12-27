#!/bin/bash

# --- 样式定义 ---
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# 1. 权限检查
if [ "$(id -u)" != "0" ]; then
    echo -e "${RED}错误: 请使用 sudo 或 root 权限运行此脚本。${NC}"
    exit 1
fi

echo -e "${CYAN}正在检查系统环境...${NC}"

# 2. Sing-box 安装状态
if command -v sing-box &> /dev/null; then
    current_version=$(sing-box version | grep 'sing-box version' | awk '{print $3}')
    echo -e "Sing-box: ${GREEN}已安装${NC} (v${current_version})"
else
    echo -e "Sing-box: ${YELLOW}未安装${NC}"
fi

# 3. IP 转发检查与开启
# 能够处理 ipv6 模块未加载的情况，防止报错
ipv4_forward=$(sysctl -n net.ipv4.ip_forward 2>/dev/null || echo 0)
ipv6_forward=$(sysctl -n net.ipv6.conf.all.forwarding 2>/dev/null || echo 0)

need_reload=0

if [ "$ipv4_forward" -eq 1 ]; then
    echo -e "IPv4 转发: ${GREEN}已开启${NC}"
else
    echo -e "IPv4 转发: ${YELLOW}未开启 (正在修复...)${NC}"
    # 使用 sed 确保幂等性（存在则修改，不存在则添加）
    if grep -q "^net.ipv4.ip_forward" /etc/sysctl.conf; then
        sed -i 's/^net.ipv4.ip_forward.*/net.ipv4.ip_forward = 1/' /etc/sysctl.conf
    else
        echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
    fi
    need_reload=1
fi

if [ "$ipv6_forward" -eq 1 ]; then
    echo -e "IPv6 转发: ${GREEN}已开启${NC}"
else
    echo -e "IPv6 转发: ${YELLOW}未开启 (正在修复...)${NC}"
    if grep -q "^net.ipv6.conf.all.forwarding" /etc/sysctl.conf; then
        sed -i 's/^net.ipv6.conf.all.forwarding.*/net.ipv6.conf.all.forwarding = 1/' /etc/sysctl.conf
    else
        echo "net.ipv6.conf.all.forwarding = 1" >> /etc/sysctl.conf
    fi
    need_reload=1
fi

# 4. 应用更改
if [ "$need_reload" -eq 1 ]; then
    sysctl -p > /dev/null 2>&1
    echo -e "${GREEN}✓ IP 转发规则已更新${NC}"
fi

# 5. 检查 nftables (sbshell 已安装，这里做二次确认)
if command -v nft &> /dev/null; then
    echo -e "Nftables: ${GREEN}已安装${NC}"
else
    echo -e "Nftables: ${RED}未安装 (请运行 sbshell 修复依赖)${NC}"
fi