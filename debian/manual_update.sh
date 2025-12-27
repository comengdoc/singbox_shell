#!/bin/bash

# --- 样式定义 ---
CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

MANUAL_FILE="/etc/sing-box/manual.conf"
SCRIPT_DIR="/etc/sing-box/scripts"

echo -e "${CYAN}正在读取订阅配置...${NC}"

if [ ! -f "$MANUAL_FILE" ]; then
    echo -e "${RED}错误: 未找到配置文件 $MANUAL_FILE${NC}"
    echo -e "${CYAN}请先运行 [导入订阅] 或 [手动输入] 进行初始化。${NC}"
    
    # 引导用户跳转
    read -rp "是否现在跳转到订阅设置? (y/n): " jump
    if [[ "$jump" =~ ^[Yy]$ ]]; then
        bash "$SCRIPT_DIR/manual_input.sh"
        exit 0
    else
        exit 1
    fi
fi

# 读取变量
BACKEND_URL=$(grep BACKEND_URL "$MANUAL_FILE" | cut -d'=' -f2-)
SUBSCRIPTION_URL=$(grep SUBSCRIPTION_URL "$MANUAL_FILE" | cut -d'=' -f2-)
TEMPLATE_URL=$(grep TEMPLATE_URL "$MANUAL_FILE" | cut -d'=' -f2-)

if [ -z "$TEMPLATE_URL" ]; then
    echo -e "${RED}配置不完整，请重新设置订阅。${NC}"
    exit 1
fi

# 构造 URL
if [ -n "$BACKEND_URL" ] && [ -n "$SUBSCRIPTION_URL" ]; then
    FULL_URL="${BACKEND_URL}/config/${SUBSCRIPTION_URL}&file=${TEMPLATE_URL}"
else
    FULL_URL="${TEMPLATE_URL}"
fi

echo -e "正在从以下地址更新配置:\n${GREEN}$FULL_URL${NC}"

# 备份
cp /etc/sing-box/config.json /etc/sing-box/config.json.backup

# 下载
if curl -s -L --connect-timeout 15 --max-time 60 "$FULL_URL" -o /etc/sing-box/config.json; then
    # 验证
    if sing-box check -c /etc/sing-box/config.json >/dev/null 2>&1; then
        echo -e "${GREEN}✓ 配置更新成功。${NC}"
        
        echo -e "${CYAN}正在重启 Sing-box...${NC}"
        sudo systemctl restart sing-box
        
        sleep 1
        if systemctl is-active --quiet sing-box; then
            echo -e "${GREEN}服务运行正常。${NC}"
        else
            echo -e "${RED}警告: 服务重启失败，请检查日志。${NC}"
        fi
    else
        echo -e "${RED}✗ 新配置验证失败，正在回滚...${NC}"
        sing-box check -c /etc/sing-box/config.json
        cp /etc/sing-box/config.json.backup /etc/sing-box/config.json
    fi
else
    echo -e "${RED}✗ 下载失败，正在回滚...${NC}"
    cp /etc/sing-box/config.json.backup /etc/sing-box/config.json
fi