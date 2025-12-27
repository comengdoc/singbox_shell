#!/bin/bash

# --- 样式定义 ---
CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 捕获中断
trap 'echo -e "\n${CYAN}操作已取消。${NC}"; exit 1' SIGINT

echo -e "${CYAN}=== 静态网络配置工具 (Debian/Armbian) ===${NC}"

# 1. 安全检查：Netplan 检测
if command -v netplan >/dev/null 2>&1 || [ -d "/etc/netplan" ]; then
    echo -e "${RED}警告: 检测到系统可能使用 Netplan (如 Ubuntu 18.04+)。${NC}"
    echo -e "${YELLOW}本脚本仅支持修改 /etc/network/interfaces。${NC}"
    echo -e "${YELLOW}在 Netplan 系统上强制修改 interfaces 可能会导致网络冲突或断连。${NC}"
    read -rp "确认要继续吗? (y/n): " force_continue
    if [[ ! "$force_continue" =~ ^[Yy]$ ]]; then
        echo "已退出以保护系统。"
        exit 1
    fi
fi

# 2. 获取当前信息
CURRENT_IP=$(ip -4 addr show | grep 'inet ' | grep -v '127.0.0.1' | awk '{print $2}' | cut -d/ -f1 | head -n 1)
CURRENT_GATEWAY=$(ip -4 route show default | awk '{print $3}' | head -n 1)
INTERFACE=$(ip -4 route show default | grep default | awk '{print $5}' | head -n 1)

if [ -z "$INTERFACE" ]; then
    echo -e "${RED}错误: 无法自动检测到默认网络接口。${NC}"
    exit 1
fi

echo -e "检测接口: ${GREEN}$INTERFACE${NC}"
echo -e "当前 IP : ${YELLOW}$CURRENT_IP${NC}"
echo -e "当前网关: ${YELLOW}$CURRENT_GATEWAY${NC}"
echo "----------------------------------------"

# 3. 输入配置
read -rp "请输入静态 IP 地址: " IP_ADDRESS
read -rp "请输入网关地址: " GATEWAY
read -rp "请输入 DNS (空格分隔, 如 8.8.8.8 1.1.1.1): " DNS_INPUT

# 4. 确认与备份
echo -e "\n${YELLOW}即将应用以下配置:${NC}"
echo "接口: $INTERFACE"
echo "IP  : $IP_ADDRESS"
echo "网关: $GATEWAY"
echo "DNS : $DNS_INPUT"

read -rp "确认修改? (y/n): " confirm
[[ ! "$confirm" =~ ^[Yy]$ ]] && exit 0

INTERFACES_FILE="/etc/network/interfaces"
RESOLV_CONF_FILE="/etc/resolv.conf"

# 备份
echo -e "${CYAN}正在备份配置文件...${NC}"
cp "$INTERFACES_FILE" "${INTERFACES_FILE}.bak.$(date +%s)"
cp "$RESOLV_CONF_FILE" "${RESOLV_CONF_FILE}.bak.$(date +%s)"

# 5. 写入配置
cat > "$INTERFACES_FILE" <<EOL
source /etc/network/interfaces.d/*

auto lo
iface lo inet loopback

allow-hotplug $INTERFACE
iface $INTERFACE inet static
    address $IP_ADDRESS
    netmask 255.255.255.0
    gateway $GATEWAY
EOL

# 写入 DNS
> "$RESOLV_CONF_FILE"
for dns in $DNS_INPUT; do
    echo "nameserver $dns" >> "$RESOLV_CONF_FILE"
done

# 6. 重启网络
echo -e "${YELLOW}正在重启网络服务 (可能会暂时断连)...${NC}"
if systemctl restart networking; then
    echo -e "${GREEN}✓ 网络服务重启成功。${NC}"
else
    echo -e "${RED}✗ 网络重启失败，正在尝试回滚 interfaces 文件...${NC}"
    cp "${INTERFACES_FILE}.bak.$(date +%s)" "$INTERFACES_FILE"
    systemctl restart networking
    exit 1
fi