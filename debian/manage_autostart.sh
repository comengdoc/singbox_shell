#!/bin/bash

# --- 样式定义 ---
CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="/etc/sing-box/scripts"
OVERRIDE_DIR="/etc/systemd/system/sing-box.service.d"
OVERRIDE_FILE="$OVERRIDE_DIR/override.conf"

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
        echo -e "${YELLOW}正在配置 Systemd Override...${NC}"
        
        # 1. 创建覆盖目录
        sudo mkdir -p "$OVERRIDE_DIR"

        # 2. 写入覆盖配置
        # 关键点：ExecStartPre 前面的 '+' 号让命令以 root 权限运行，解决权限不足问题
        cat <<EOF | sudo tee "$OVERRIDE_FILE" > /dev/null
[Unit]
Description=Sing-box Service with Auto Firewall Rules
After=network.target network-online.target

[Service]
# (+) 强制以 root 权限运行防火墙脚本
ExecStartPre=+$SCRIPT_DIR/manage_autostart.sh apply_firewall
# 赋予必要的网络权限
AmbientCapabilities=CAP_NET_BIND_SERVICE CAP_NET_ADMIN CAP_NET_RAW
CapabilityBoundingSet=CAP_NET_BIND_SERVICE CAP_NET_ADMIN CAP_NET_RAW
EOF
        
        # 3. 赋予脚本执行权限 (防止 203/EXEC 错误)
        sudo chmod +x "$SCRIPT_DIR/manage_autostart.sh"
        
        # 4. 重载并启用
        sudo systemctl daemon-reload
        sudo systemctl enable sing-box
        
        echo -e "${GREEN}✓ 自启配置已更新。防火墙规则将在每次 sing-box 启动前自动应用。${NC}"
        
        # 询问是否立即重启生效
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
        echo -e "${YELLOW}正在移除自启托管配置...${NC}"
        if [ -f "$OVERRIDE_FILE" ]; then
            sudo rm -f "$OVERRIDE_FILE"
            sudo systemctl daemon-reload
            echo -e "${GREEN}✓ 已移除 Systemd Override 配置。${NC}"
        else
            echo -e "${GREEN}未检测到托管配置，无需操作。${NC}"
        fi
        ;;
    0)
        exit 0
        ;;
    *)
        echo -e "${RED}无效输入${NC}"
        ;;
esac