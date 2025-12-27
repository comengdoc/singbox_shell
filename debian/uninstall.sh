#!/bin/bash

# 定义颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${RED}==============================================${NC}"
echo -e "${RED}       Sing-box 彻底卸载脚本 (Uninstall)       ${NC}"
echo -e "${RED}==============================================${NC}"
echo -e "${YELLOW}警告: 此操作将删除所有配置、日志、脚本和定时任务。${NC}"
read -rp "确认要卸载吗? (输入 y 确认): " confirm

if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "操作已取消。"
    exit 0
fi

echo -e "\n${YELLOW}1. 停止并禁用服务...${NC}"
sudo systemctl stop sing-box
sudo systemctl disable sing-box
sudo rm -rf /etc/systemd/system/sing-box.service.d

echo -e "${YELLOW}2. 清理防火墙规则...${NC}"
# 彻底清空规则，恢复网络直连状态
sudo nft flush ruleset

echo -e "${YELLOW}3. 删除文件和目录...${NC}"
sudo rm -rf /etc/sing-box
sudo rm -rf /var/log/sing-box*
sudo rm -f /usr/local/bin/sb

echo -e "${YELLOW}4. 清理定时任务...${NC}"
crontab -l | grep -v '/etc/sing-box' | crontab -

echo -e "${YELLOW}5. 移除 Sing-box 主程序 (可选)...${NC}"
read -rp "是否同时卸载 sing-box 主程序? (y/n): " remove_pkg
if [[ "$remove_pkg" =~ ^[Yy]$ ]]; then
    sudo apt-get remove --purge -y sing-box sing-box-beta 2>/dev/null
    sudo apt-get autoremove -y
    echo -e "${GREEN}主程序已卸载。${NC}"
else
    echo "保留主程序。"
fi

sudo systemctl daemon-reload
echo -e "\n${GREEN}✅ 卸载完成！系统已清理干净。${NC}"