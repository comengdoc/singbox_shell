#!/bin/bash

# --- 样式定义 ---
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

DEFAULTS_FILE="/etc/sing-box/defaults.conf"
mkdir -p "$(dirname "$DEFAULTS_FILE")"

# 读取现有配置 (如果存在)
if [ -f "$DEFAULTS_FILE" ]; then
    CUR_BACKEND=$(grep BACKEND_URL "$DEFAULTS_FILE" | cut -d '=' -f2)
    CUR_SUB=$(grep SUBSCRIPTION_URL "$DEFAULTS_FILE" | cut -d '=' -f2)
    CUR_TPROXY=$(grep TPROXY_TEMPLATE_URL "$DEFAULTS_FILE" | cut -d '=' -f2)
    CUR_TUN=$(grep TUN_TEMPLATE_URL "$DEFAULTS_FILE" | cut -d '=' -f2)
fi

echo -e "${CYAN}=== 设置默认订阅参数 ===${NC}"
echo -e "${YELLOW}提示: 直接回车将保留当前值/空值${NC}\n"

# 交互输入
read -rp "后端地址 [当前: ${CUR_BACKEND:-无}]: " IN_BACKEND
BACKEND_URL=${IN_BACKEND:-$CUR_BACKEND}

read -rp "订阅地址 [当前: ${CUR_SUB:-无}]: " IN_SUB
SUBSCRIPTION_URL=${IN_SUB:-$CUR_SUB}

read -rp "TProxy 模板地址 [当前: ${CUR_TPROXY:-无}]: " IN_TPROXY
TPROXY_TEMPLATE_URL=${IN_TPROXY:-$CUR_TPROXY}

read -rp "TUN 模板地址 [当前: ${CUR_TUN:-无}]: " IN_TUN
TUN_TEMPLATE_URL=${IN_TUN:-$CUR_TUN}

# 写入配置
cat > "$DEFAULTS_FILE" <<EOF
BACKEND_URL=$BACKEND_URL
SUBSCRIPTION_URL=$SUBSCRIPTION_URL
TPROXY_TEMPLATE_URL=$TPROXY_TEMPLATE_URL
TUN_TEMPLATE_URL=$TUN_TEMPLATE_URL
EOF

echo -e "\n${GREEN}✓ 默认配置已更新到 $DEFAULTS_FILE${NC}"