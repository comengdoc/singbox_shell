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
# 如果存在 Systemd Override (自启托管配置)，一并删除
sudo rm -rf /etc/systemd/system/sing-box.service.d

echo -e "${YELLOW}2. 清理防火墙规则...${NC}"
# 彻底清空 nftables 规则，恢复直连
sudo nft flush ruleset
# 如果安装了 ufw 且需要重置，可以在这里操作，默认暂不重置 ufw 以免断连 SSH

echo -e "${YELLOW}3. 删除文件和目录...${NC}"
# 删除主目录
sudo rm -rf /etc/sing-box
# 删除日志目录 (如果有)
sudo rm -rf /var/log/sing-box*
# 删除快捷命令
sudo rm -f /usr/local/bin/sb

echo -e "${YELLOW}4. 清理定时任务 (Crontab)...${NC}"
# 删除包含 sing-box 路径的所有定时任务
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

# 重载 Systemd
sudo systemctl daemon-reload

echo -e "\n${GREEN}✅ 卸载完成！系统已清理干净。${NC}"
echo -e "提示: 防火墙规则已重置。如果之前开启了 UFW，请手动检查 'ufw status'。"
