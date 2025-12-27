#!/bin/bash

# --- 样式定义 ---
CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

MANUAL_FILE="/etc/sing-box/manual.conf"
DEFAULTS_FILE="/etc/sing-box/defaults.conf"

# 获取当前模式 (用于推荐默认模板)
if [ -f "/etc/sing-box/mode.conf" ]; then
    MODE=$(grep "^MODE=" /etc/sing-box/mode.conf | cut -d'=' -f2)
else
    MODE="TUN" # 默认 fallback
fi

echo -e "${CYAN}=== 订阅与配置导入 ===${NC}"

# --- 输入环节 ---

# 1. 后端地址
DEFAULT_BACKEND=$(grep BACKEND_URL "$DEFAULTS_FILE" 2>/dev/null | cut -d'=' -f2-)
read -rp "1. 请输入后端地址 [回车用默认: ${DEFAULT_BACKEND:0:20}...]: " IN_BACKEND
BACKEND_URL="${IN_BACKEND:-$DEFAULT_BACKEND}"

# 2. 订阅地址
DEFAULT_SUB=$(grep SUBSCRIPTION_URL "$DEFAULTS_FILE" 2>/dev/null | cut -d'=' -f2-)
read -rp "2. 请输入订阅地址 [回车用默认: ${DEFAULT_SUB:0:20}...]: " IN_SUB
SUBSCRIPTION_URL="${IN_SUB:-$DEFAULT_SUB}"

# 3. 模板地址
if [ "$MODE" = "TProxy" ]; then
    DEFAULT_TPL=$(grep TPROXY_TEMPLATE_URL "$DEFAULTS_FILE" 2>/dev/null | cut -d'=' -f2-)
else
    DEFAULT_TPL=$(grep TUN_TEMPLATE_URL "$DEFAULTS_FILE" 2>/dev/null | cut -d'=' -f2-)
fi
read -rp "3. 请输入模板地址 [回车用默认: ${DEFAULT_TPL:0:20}...]: " IN_TPL
TEMPLATE_URL="${IN_TPL:-$DEFAULT_TPL}"

# --- 确认环节 ---
echo -e "\n${YELLOW}即将写入以下配置:${NC}"
echo "----------------------------------------"
echo -e "后端: ${GREEN}$BACKEND_URL${NC}"
echo -e "订阅: ${GREEN}$SUBSCRIPTION_URL${NC}"
echo -e "模板: ${GREEN}$TEMPLATE_URL${NC}"
echo "----------------------------------------"

read -rp "确认并开始生成? (y/n): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "操作取消。"
    exit 0
fi

# --- 保存与生成 ---
cat > "$MANUAL_FILE" <<EOF
BACKEND_URL=$BACKEND_URL
SUBSCRIPTION_URL=$SUBSCRIPTION_URL
TEMPLATE_URL=$TEMPLATE_URL
EOF

# 构造 URL (处理可能的 URL 编码问题或空值)
if [ -n "$BACKEND_URL" ] && [ -n "$SUBSCRIPTION_URL" ]; then
    # 简单的拼接，如果后端有特殊字符可能需要更复杂的处理
    FULL_URL="${BACKEND_URL}/config/${SUBSCRIPTION_URL}&file=${TEMPLATE_URL}"
else
    FULL_URL="${TEMPLATE_URL}"
fi

echo -e "${CYAN}正在下载配置文件...${NC}"
echo -e "链接: $FULL_URL"

# 备份
[ -f "/etc/sing-box/config.json" ] && cp /etc/sing-box/config.json /etc/sing-box/config.json.backup

# 下载循环
MAX_RETRIES=3
count=0
success=false

while [ $count -lt $MAX_RETRIES ]; do
    if curl -s -L --connect-timeout 10 --max-time 30 "$FULL_URL" -o /etc/sing-box/config.json; then
        # 验证
        if sing-box check -c /etc/sing-box/config.json > /dev/null 2>&1; then
            echo -e "${GREEN}✓ 配置文件下载并验证成功！${NC}"
            success=true
            break
        else
            echo -e "${RED}✗ 下载成功但格式验证失败 (JSON 错误)。${NC}"
            # 打印错误详情
            sing-box check -c /etc/sing-box/config.json
        fi
    else
        echo -e "${RED}✗ 下载失败 (尝试 $((count+1))/$MAX_RETRIES)...${NC}"
    fi
    count=$((count+1))
    sleep 2
done

if [ "$success" = true ]; then
    # 提示重启
    read -rp "是否立即重启 Sing-box 服务? (y/n): " restart_now
    if [[ "$restart_now" =~ ^[Yy]$ ]]; then
        sudo systemctl restart sing-box
        echo -e "${GREEN}服务已重启。${NC}"
    fi
else
    echo -e "${RED}多次尝试失败，正在恢复备份...${NC}"
    [ -f "/etc/sing-box/config.json.backup" ] && cp /etc/sing-box/config.json.backup /etc/sing-box/config.json
    exit 1
fi