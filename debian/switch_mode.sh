#!/bin/bash

# --- 样式定义 ---
CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

CONF_FILE="/etc/sing-box/mode.conf"
SCRIPT_DIR="/etc/sing-box/scripts"

# 检查当前模式
if [ -f "$CONF_FILE" ]; then
    CURRENT_MODE=$(grep "^MODE=" "$CONF_FILE" | cut -d'=' -f2)
else
    CURRENT_MODE="未知"
fi

echo -e "${CYAN}=== Sing-box 运行模式切换 ===${NC}"
echo -e "当前模式: ${YELLOW}${CURRENT_MODE}${NC}"
echo "-----------------------------------"
echo "1. TProxy 模式 (透明代理，推荐做网关使用)"
echo "2. TUN 模式    (虚拟网卡，通用性好)"
echo "0. 取消"
echo "-----------------------------------"

read -rp "请选择目标模式: " choice

case $choice in
    1) TARGET_MODE="TProxy" ;;
    2) TARGET_MODE="TUN" ;;
    *) echo "已取消"; exit 0 ;;
esac

if [ "$TARGET_MODE" == "$CURRENT_MODE" ]; then
    echo -e "${YELLOW}当前已经是 $TARGET_MODE 模式，无需切换。${NC}"
    exit 0
fi

# 执行切换逻辑
echo -e "${CYAN}正在切换到 $TARGET_MODE 模式...${NC}"

# 1. 写入配置
echo "MODE=$TARGET_MODE" | sudo tee "$CONF_FILE" > /dev/null

# 2. 清理旧规则 (重要!)
if [ -f "$SCRIPT_DIR/clean_nft.sh" ]; then
    echo -e "${YELLOW}清理旧防火墙规则...${NC}"
    bash "$SCRIPT_DIR/clean_nft.sh"
else
    # 简单的后备清理
    nft delete table inet sing-box 2>/dev/null
fi

echo -e "${GREEN}✓ 模式配置已更新为: $TARGET_MODE${NC}"

# 3. 询问重启
echo -e "\n${RED}注意：模式切换需要重启服务并重新加载防火墙规则才能生效。${NC}"
read -rp "是否立即重启 Sing-box? (y/n): " confirm_restart

if [[ "$confirm_restart" =~ ^[Yy]$ ]]; then
    echo -e "${CYAN}正在重启服务...${NC}"
    # 调用启动脚本，它会自动根据 mode.conf 应用对应的防火墙
    bash "$SCRIPT_DIR/start_singbox.sh"
else
    echo -e "${YELLOW}请稍后手动运行 start_singbox.sh 或重启系统以生效。${NC}"
fi