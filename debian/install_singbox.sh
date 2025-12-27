#!/bin/bash

# --- 样式定义 ---
CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# --- 辅助函数：配置 Systemd 权限 ---
configure_systemd_override() {
    echo -e "${CYAN}正在配置 Sing-box 服务权限 (Drop-in Override)...${NC}"
    
    # 创建 override 目录
    sudo mkdir -p /etc/systemd/system/sing-box.service.d

    # 写入配置：指定用户和必要的能力(Capability)
    # AmbientCapabilities 是必须的，否则非 root 用户无法绑定低端口或进行 TProxy
    cat <<EOF | sudo tee /etc/systemd/system/sing-box.service.d/override.conf > /dev/null
[Service]
User=sing-box
Group=sing-box
# 允许绑定特权端口和透明代理
AmbientCapabilities=CAP_NET_BIND_SERVICE CAP_NET_ADMIN CAP_NET_RAW
CapabilityBoundingSet=CAP_NET_BIND_SERVICE CAP_NET_ADMIN CAP_NET_RAW
# 允许写入状态目录
StateDirectory=sing-box
StateDirectoryMode=0700
EOF

    echo -e "${GREEN}✓ Systemd 覆盖配置已创建。${NC}"
    sudo systemctl daemon-reload
}

# --- 主逻辑 ---

# 1. 检查安装
if command -v sing-box &> /dev/null; then
    current_ver=$(sing-box version | awk '/version/{print $3}')
    echo -e "${YELLOW}Sing-box 已安装 (v${current_ver})，跳过基础安装。${NC}"
    # 即使安装了，也要确保权限配置正确
    if ! id sing-box &>/dev/null; then
        echo "补全 sing-box 用户..."
        sudo useradd --system --no-create-home --shell /usr/sbin/nologin sing-box
    fi
else
    # 2. 添加仓库并安装
    echo -e "${CYAN}正在配置官方源...${NC}"
    sudo mkdir -p /etc/apt/keyrings
    sudo curl -fsSL https://sing-box.app/gpg.key -o /etc/apt/keyrings/sagernet.asc
    sudo chmod a+r /etc/apt/keyrings/sagernet.asc
    
    echo "Types: deb
URIs: https://deb.sagernet.org/
Suites: *
Components: *
Enabled: yes
Signed-By: /etc/apt/keyrings/sagernet.asc
" | sudo tee /etc/apt/sources.list.d/sagernet.sources > /dev/null

    echo -e "${CYAN}更新软件源...${NC}"
    sudo apt-get update -qq

    # 3. 版本选择
    while true; do
        echo -e "${CYAN}请选择安装版本:${NC}"
        echo "1. 稳定版 (Stable)"
        echo "2. 测试版 (Beta)"
        read -rp "输入数字 (1/2): " v_choice
        case $v_choice in
            1) sudo apt-get install sing-box -y; break ;;
            2) sudo apt-get install sing-box-beta -y; break ;;
            *) echo -e "${RED}输入无效${NC}" ;;
        esac
    done
fi

# 4. 权限与目录修复 (核心部分)
if command -v sing-box &> /dev/null; then
    echo -e "${CYAN}正在修复权限与目录...${NC}"
    
    # 确保用户存在
    if ! id sing-box &>/dev/null; then
        sudo useradd --system --no-create-home --shell /usr/sbin/nologin sing-box
    fi

    # 修复目录权限
    for dir in "/var/lib/sing-box" "/etc/sing-box"; do
        sudo mkdir -p "$dir"
        sudo chown -R sing-box:sing-box "$dir"
        sudo chmod 770 "$dir"
    done
    
    # 配置 Systemd
    configure_systemd_override

    # 重启服务
    echo -e "${CYAN}正在重启服务...${NC}"
    if sudo systemctl restart sing-box; then
        version=$(sing-box version | grep 'sing-box version' | awk '{print $3}')
        echo -e "${GREEN}Sing-box 安装/配置成功！版本: ${version}${NC}"
    else
        echo -e "${RED}服务启动失败，请检查日志: journalctl -u sing-box -e${NC}"
    fi
else
    echo -e "${RED}安装失败！${NC}"
fi