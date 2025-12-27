#!/bin/bash

# 定义颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${RED}==============================================${NC}"
echo -e "${RED}    Sing-box 彻底卸载脚本 (Docker安全版)       ${NC}"
echo -e "${RED}==============================================${NC}"
echo -e "${YELLOW}警告: 此操作将删除 Sing-box 所有文件和配置。${NC}"
read -rp "确认要卸载吗? (输入 y 确认): " confirm

if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "操作已取消。"
    exit 0
fi

echo -e "\n${YELLOW}1. 停止并禁用服务...${NC}"
sudo systemctl stop sing-box
sudo systemctl disable sing-box
sudo rm -rf /etc/systemd/system/sing-box.service.d

echo -e "${YELLOW}2. 清理 Sing-box 防火墙规则...${NC}"
# --- 关键修改：只删除 Sing-box 专用表，不碰 Docker 规则 ---
if nft list table inet sing-box >/dev/null 2>&1; then
    sudo nft delete table inet sing-box
    echo "已清理 TProxy 规则表。"
else
    echo "未检测到 TProxy 规则表，跳过。"
fi

# 对于 TUN 模式的 NAT 规则，因为是混在 ip nat 表里的
# 为了安全，我们不强行 flush，而是建议用户重启 Docker
echo -e "${YELLOW}提示: NAT 规则保留以防止破坏 Docker 网络。${NC}"

echo -e "${YELLOW}3. 删除文件和目录...${NC}"
sudo rm -rf /etc/sing-box
sudo rm -rf /var/log/sing-box*
sudo rm -f /usr/local/bin/sb

echo -e "${YELLOW}4. 清理定时任务...${NC}"
crontab -l | grep -v '/etc/sing-box' | crontab -

echo -e "${YELLOW}5. 移除主程序...${NC}"
read -rp "是否同时卸载 sing-box 主程序? (y/n): " remove_pkg
if [[ "$remove_pkg" =~ ^[Yy]$ ]]; then
    sudo apt-get remove --purge -y sing-box sing-box-beta 2>/dev/null
    sudo apt-get autoremove -y
    echo -e "${GREEN}主程序已卸载。${NC}"
fi

sudo systemctl daemon-reload

echo -e "\n${GREEN}✅ 卸载完成！${NC}"

# --- Docker 环境检测与提示 ---
if command -v docker >/dev/null 2>&1 && systemctl is-active --quiet docker; then
    echo -e "\n${YELLOW}检测到系统正在运行 Docker。${NC}"
    echo -e "为了确保网络规则完全干净且不影响容器，建议您执行一次 Docker 重启："
    echo -e "${GREEN}sudo systemctl restart docker${NC}"
fi