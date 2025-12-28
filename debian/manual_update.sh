#!/bin/bash

# --- 样式定义 ---
CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 定义配置文件路径
# 优先读取 manual.conf，如果不存在或变量为空，脚本兼容性处理会自动应对
MANUAL_FILE="/etc/sing-box/manual.conf"
SCRIPT_DIR="/etc/sing-box/scripts"

echo -e "${CYAN}正在读取订阅配置...${NC}"

if [ ! -f "$MANUAL_FILE" ]; then
    echo -e "${RED}错误: 未找到配置文件 $MANUAL_FILE${NC}"
    echo -e "${CYAN}请先运行 [修改默认参数] 或 [导入订阅] 进行初始化。${NC}"
    
    read -rp "是否现在跳转到订阅设置? (y/n): " jump
    if [[ "$jump" =~ ^[Yy]$ ]]; then
        # 尝试调用手动输入脚本，如果不存在则提示
        if [ -f "$SCRIPT_DIR/manual_input.sh" ]; then
            bash "$SCRIPT_DIR/manual_input.sh"
            exit 0
        else
             echo -e "${RED}找不到设置脚本，请检查安装。${NC}"
             exit 1
        fi
    else
        exit 1
    fi
fi

# --- 核心修复：使用 source 读取变量，而不是 grep ---
# 这样可以确保读取到你在选项4中写入的最新值
source "$MANUAL_FILE"

# --- 变量映射 (兼容性修复) ---
# 下面的逻辑确保无论配置文件里用的是什么变量名，脚本都能读懂
# 1. 订阅链接 (SubUrl / SUBSCRIPTION_URL)
LINK="${SUBSCRIPTION_URL:-$SubUrl}"

# 2. 转换后端 (BackendUrl / BACKEND_URL)
API="${BACKEND_URL:-$BackendUrl}"

# 3. 模板文件 (JsonPath / TEMPLATE_URL / Template)
# 只要这三个里有一个有值，Template 就会被赋值
TEMPLATE="${TEMPLATE_URL:-${JsonPath:-$Template}}"

# --- 检查变量是否读取成功 ---
if [ -z "$TEMPLATE" ]; then
    echo -e "${RED}错误：读取到的模板参数为空！${NC}"
    echo -e "${YELLOW}可能原因：配置文件中变量名不匹配。${NC}"
    echo -e "当前读取文件: $MANUAL_FILE"
    exit 1
fi

# --- 构造下载地址 ---
# 如果有后端和订阅链接，则进行转换拼接
if [ -n "$API" ] && [ -n "$LINK" ]; then
    # 这里使用了标准的 sing-box 转换格式
    # 关键点：使用读取到的 $TEMPLATE 变量
    FULL_URL="${API}/config/${LINK}&file=${TEMPLATE}"
else
    # 如果只有模板（比如直接下载模式），则直接使用模板链接
    FULL_URL="${TEMPLATE}"
fi

echo -e "正在从以下地址更新配置:\n${GREEN}$FULL_URL${NC}"

# --- 备份与下载逻辑 (保持原样) ---
CONFIG_PATH="/etc/sing-box/config.json"
BACKUP_PATH="/etc/sing-box/config.json.backup"

# 备份
cp "$CONFIG_PATH" "$BACKUP_PATH" 2>/dev/null

# 下载
echo -e "${CYAN}正在下载配置...${NC}"
if curl -s -L --connect-timeout 15 --max-time 60 "$FULL_URL" -o "$CONFIG_PATH"; then
    # 验证 JSON 格式
    if sing-box check -c "$CONFIG_PATH" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ 配置下载并验证成功。${NC}"
        
        echo -e "${CYAN}正在重启 Sing-box...${NC}"
        # 尝试使用 systemctl 重启
        sudo systemctl restart sing-box
        
        sleep 2
        if systemctl is-active --quiet sing-box; then
            echo -e "${GREEN}服务运行正常: ● Active${NC}"
        else
            echo -e "${RED}警告: 服务未能正常启动，请检查 'systemctl status sing-box'${NC}"
            echo -e "${YELLOW}提示: 可能是端口冲突或内核不兼容。${NC}"
        fi
    else
        echo -e "${RED}✗ 下载的文件格式错误 (Check Failed)。${NC}"
        echo -e "${YELLOW}正在回滚到旧配置...${NC}"
        cp "$BACKUP_PATH" "$CONFIG_PATH"
        sudo systemctl restart sing-box
    fi
else
    echo -e "${RED}✗ 网络请求失败 (Curl Failed)。${NC}"
    echo -e "${YELLOW}正在回滚到旧配置...${NC}"
    cp "$BACKUP_PATH" "$CONFIG_PATH"
fi