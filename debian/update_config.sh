#!/bin/bash

# --- 样式定义 ---
CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

CONFIG_FILE="/etc/sing-box/config.json"
MANUAL_FILE="/etc/sing-box/manual.conf"
SCRIPT_DIR="/etc/sing-box/scripts"

echo -e "${CYAN}=== Sing-box 配置更新 ===${NC}"

# 策略：优先使用 manual.conf 中的订阅信息重新生成，
# 如果没有订阅信息，才去下载静态链接。

if [ -f "$MANUAL_FILE" ]; then
    echo -e "${GREEN}检测到订阅配置文件 (manual.conf)。${NC}"
    echo -e "${CYAN}正在调用订阅更新脚本...${NC}"
    
    # 直接调用 manual_update.sh，复用其逻辑
    if [ -f "$SCRIPT_DIR/manual_update.sh" ]; then
        bash "$SCRIPT_DIR/manual_update.sh"
        exit $?
    else
        echo -e "${RED}错误: 找不到 manual_update.sh 脚本。${NC}"
        # Fallback to logic below
    fi
fi

# --- 如果没有订阅配置，走静态链接逻辑 ---

CONFIG_URL_FILE="/etc/sing-box/config.url"
DEFAULT_URL="https://raw.githubusercontent.com/comengdoc/singbox_shell/refs/heads/main/config/server/config.json"

echo -e "${YELLOW}未检测到动态订阅配置，将使用直接下载模式。${NC}"

# 读取或请求 URL
if [ -s "$CONFIG_URL_FILE" ]; then
    URL=$(cat "$CONFIG_URL_FILE")
    echo -e "当前来源: ${YELLOW}$URL${NC}"
    read -rp "是否修改下载链接? (y/n): " change
    if [[ "$change" =~ ^[Yy]$ ]]; then
        read -rp "新链接: " URL
        echo "$URL" > "$CONFIG_URL_FILE"
    fi
else
    read -rp "请输入配置下载链接 [回车使用默认]: " URL
    URL=${URL:-$DEFAULT_URL}
    echo "$URL" > "$CONFIG_URL_FILE"
fi

# 下载
echo -e "${CYAN}正在下载...${NC}"
cp "$CONFIG_FILE" "${CONFIG_FILE}.bak" 2>/dev/null

if wget -q -O "$CONFIG_FILE" "$URL"; then
    if sing-box check -c "$CONFIG_FILE" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ 下载并验证成功。${NC}"
        systemctl restart sing-box
    else
        echo -e "${RED}✗ 配置格式错误，已回滚。${NC}"
        mv "${CONFIG_FILE}.bak" "$CONFIG_FILE"
    fi
else
    echo -e "${RED}✗ 下载失败。${NC}"
    mv "${CONFIG_FILE}.bak" "$CONFIG_FILE"
fi