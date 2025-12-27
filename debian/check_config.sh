#!/bin/bash

# --- 样式定义 ---
CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

CONFIG_FILE="/etc/sing-box/config.json"

echo -e "${CYAN}正在验证配置文件一致性...${NC}"

# 1. 检查文件是否存在
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}错误: 配置文件不存在 ($CONFIG_FILE)${NC}"
    exit 1
fi

# 2. 检查文件是否为空
if [ ! -s "$CONFIG_FILE" ]; then
    echo -e "${RED}错误: 配置文件为空 ($CONFIG_FILE)${NC}"
    exit 1
fi

# 3. 使用 sing-box 原生命令检查语法
if sing-box check -c "$CONFIG_FILE" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ 配置文件格式正确 (Syntax OK)${NC}"
    exit 0
else
    echo -e "${RED}✗ 配置文件格式错误！以下是详细报错：${NC}"
    sing-box check -c "$CONFIG_FILE"
    exit 1
fi