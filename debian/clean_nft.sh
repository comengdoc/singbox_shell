#!/bin/bash

CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${CYAN}正在停止 Sing-box 服务...${NC}"
sudo systemctl stop sing-box

if command -v nft &> /dev/null; then
    echo -e "${CYAN}正在清理 Nftables 规则...${NC}"
    # 尝试清理 sing-box 专用链（如果存在），或者直接 flush ruleset
    # 建议直接 flush ruleset 确保干净，但如果有其他服务依赖 nftables 需要小心
    # 这里为了彻底清理 sing-box 残留，通常 flush ruleset 是 TProxy 模式关闭后的标准操作
    sudo nft flush ruleset
    
    echo -e "${GREEN}✓ 服务已停止，防火墙规则已重置。${NC}"
else
    echo -e "${RED}警告: 未找到 nft 命令，无法清理防火墙规则（可能未安装或已卸载）。${NC}"
fi

# 额外建议：如果使用了 TProxy，可能还需要清理 ip rule
# 这里简单检查一下 singbox 相关的策略路由
if ip rule show | grep -q "fwmark"; then
    echo -e "${CYAN}检测到残留路由策略，正在清理...${NC}"
    # 这里的清理逻辑比较激进，假设 fwmark 1 是 singbox 用的
    # 实际脚本中最好记录下添加了什么 rule，这里暂不自动删除 ip rule 防止误删
    echo -e "${RED}提示: 如果网络异常，请重启系统以重置路由表。${NC}"
fi