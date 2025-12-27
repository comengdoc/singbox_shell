#!/bin/bash

# --- 样式定义 ---
CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# --- 自动模式 ---
if [ "$1" == "--auto" ]; then
    if ! command -v ufw &>/dev/null; then
        apt-get update -qq && apt-get install -y ufw
    fi
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow ssh
    ufw allow 80/tcp
    ufw allow 443/tcp
    echo "y" | ufw enable
    exit 0
fi

# --- 交互模式 ---
echo -e "${CYAN}=== UFW 防火墙配置工具 ===${NC}"

# 1. 安装检查
if ! command -v ufw &>/dev/null; then
    echo -e "${YELLOW}正在安装 UFW...${NC}"
    apt-get update -qq && apt-get install -y ufw
else
    echo -e "${GREEN}UFW 已安装。${NC}"
fi

# 2. 基础规则
echo -e "${CYAN}正在应用基础规则 (允许 SSH/HTTP/HTTPS)...${NC}"
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 80/tcp
ufw allow 443/tcp

# 3. 自定义端口
echo -e "\n${YELLOW}请输入额外放行的端口 (空格分隔, 如 7890 8080):${NC}"
read -rp "端口列表: " ports
for port in $ports; do
    if [[ "$port" =~ ^[0-9]+$ ]]; then
        ufw allow "$port"
        echo -e "已放行: $port"
    fi
done

# 4. 启用
echo -e "${CYAN}正在启用防火墙...${NC}"
echo "y" | ufw enable
echo -e "${GREEN}✓ UFW 已启用。${NC}"

# 5. SSH 端口修改 (高级)
echo -e "\n${RED}=== 高级选项: 修改 SSH 端口 ===${NC}"
read -rp "是否修改 SSH 默认端口? (y/n): " mod_ssh
if [[ "$mod_ssh" =~ ^[Yy]$ ]]; then
    read -rp "输入新端口 (1024-65535): " new_port
    if [[ "$new_port" =~ ^[0-9]+$ ]] && [ "$new_port" -gt 1024 ]; then
        # 放行新端口
        ufw allow "$new_port/tcp"
        
        # 修改配置 (使用更安全的 sed)
        cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
        if grep -q "^Port " /etc/ssh/sshd_config; then
            sed -i "s/^Port .*/Port $new_port/" /etc/ssh/sshd_config
        else
            echo "Port $new_port" >> /etc/ssh/sshd_config
        fi
        
        echo -e "${GREEN}配置已修改。正在重启 SSH 服务...${NC}"
        systemctl restart sshd
        echo -e "${RED}警告: 请不要关闭当前终端！请新开一个终端测试端口 $new_port 是否能连接！${NC}"
    else
        echo "端口无效，跳过。"
    fi
fi