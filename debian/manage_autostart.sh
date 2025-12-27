#!/bin/bash

# --- 样式定义 ---
CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="/etc/sing-box/scripts"
OVERRIDE_DIR="/etc/systemd/system/sing-box.service.d"
# [修复] 改名：使用独立的文件名，不与 install 脚本冲突
FIREWALL_CONF="$OVERRIDE_DIR/firewall_hook.conf"

# 应用防火墙的包装函数 (供 systemd 调用)
apply_firewall_logic() {
    # 读取模式
    if [ -f "/etc/sing-box/mode.conf" ]; then
        MODE=$(grep "^MODE=" /etc/sing-box/mode.conf | cut -d'=' -f2)
    else
        echo "未找到模式配置文件，默认跳过防火墙设置。"
        exit 0
    fi

    echo "正在根据模式 ($MODE) 应用防火墙规则..."
    if [ "$MODE" = "TProxy" ]; then
        bash "$SCRIPT_DIR/configure_tproxy.sh"
    elif [ "$MODE" = "TUN" ]; then
        bash "$SCRIPT_DIR/configure_tun.sh"
    else
        echo "当前模式不需要特定的防火墙规则。"
    fi
}

# 供外部调用 (ExecStartPre)
if [ "$1" = "apply_firewall" ]; then
    apply_firewall_logic
    exit $?
fi

# --- 菜单逻辑 ---

echo -e "${CYAN}=== Sing-box 开机自启与防火墙托管 ===${NC}"
echo "1. 启用 (Systemd 托管防火墙规则)"
echo "2. 禁用 (仅保留基础服务)"
echo "0. 取消"
read -rp "请选择: " choice

case $choice in
    1)
        echo -e "${YELLOW}正在配置 Systemd 防火墙钩子...${NC}"
        
        # 1. 创建覆盖目录
        sudo mkdir -p "$OVERRIDE_DIR"

        # 2. 写入防火墙专用配置 (firewall_hook.conf)
        # 注意：这里我们不再写入 User=...，因为那是 install_singbox.sh 负责的
        # systemd 会自动合并这两个文件。
        cat <<EOF | sudo tee "$FIREWALL_CONF" > /dev/null
[Unit]
Description=Sing-box Service with Auto Firewall Rules
After=network.target network-online.target

[Service]
# (+) 强制以 root 权限运行防火墙脚本，因为 iptables/nft 需要 root
ExecStartPre=+$SCRIPT_DIR/manage_autostart.sh apply_firewall
EOF
        
        # 3. 赋予脚本执行权限
        sudo chmod +x "$SCRIPT_DIR/manage_autostart.sh"
        
        # 4. 重载并启用
        sudo systemctl daemon-reload
        sudo systemctl enable sing-box
        
        echo -e "${GREEN}✓ 自启配置已更新 (文件: firewall_hook.conf)。${NC}"
        echo -e "${GREEN}Systemd 将自动合并基础权限与防火墙规则。${NC}"
        
        read -rp "是否立即重启服务以应用配置? (y/n): " reboot_choice
        if [[ "$reboot_choice" =~ ^[Yy]$ ]]; then
            sudo systemctl stop sing-box
            sudo systemctl restart sing-box
            if systemctl is-active --quiet sing-box; then
                echo -e "${GREEN}服务重启成功。${NC}"
            else
                echo -e "${RED}服务启动失败。请运行 [8] 查看日志。${NC}"
            fi
        fi
        ;;
    2)
        echo -e "${YELLOW}正在移除防火墙托管配置...${NC}"
        # 仅删除防火墙钩子，不删除基础 User 配置
        if [ -f "$FIREWALL_CONF" ]; then
            sudo rm -f "$FIREWALL_CONF"
            sudo systemctl daemon-reload
            echo -e "${GREEN}✓ 已移除防火墙自动加载规则 (firewall_hook.conf)。${NC}"
        else
            # 兼容旧版本：尝试删除旧的错误文件，但前提是确认它不是只有 User 配置
            # 为安全起见，这里只清理新定义的文件名
            echo -e "${GREEN}未检测到防火墙挂钩配置。${NC}"
        fi
        ;;
    0)
        exit 0
        ;;
    *)
        echo -e "${RED}无效输入${NC}"
        ;;
esac