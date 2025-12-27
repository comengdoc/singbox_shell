#!/bin/bash

# --- 样式定义 ---
CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

UI_DIR="/etc/sing-box/ui"
BACKUP_DIR="/tmp/sing-box_ui_backup"
TEMP_DIR="/tmp/sing-box_ui_temp"

# URLs
ZASHBOARD="https://ghfast.top/https://github.com/Zephyruso/zashboard/archive/refs/heads/gh-pages.zip"
METACUBEXD="https://ghfast.top/https://github.com/MetaCubeX/metacubexd/archive/refs/heads/gh-pages.zip"
YACD="https://ghfast.top/https://github.com/MetaCubeX/Yacd-meta/archive/refs/heads/gh-pages.zip"

# 1. 依赖检查
if ! command -v unzip &>/dev/null; then
    echo -e "${CYAN}正在安装 unzip...${NC}"
    apt-get update -qq && apt-get install -y unzip
fi

# 2. 安装逻辑
install_ui() {
    local url="$1"
    local name="$2"

    echo -e "${CYAN}正在安装 $name ...${NC}"
    
    # 准备目录
    rm -rf "$TEMP_DIR"
    mkdir -p "$TEMP_DIR" "$UI_DIR" "$BACKUP_DIR"

    # 备份
    if [ "$(ls -A $UI_DIR)" ]; then
        echo "备份当前 UI..."
        cp -r "$UI_DIR"/* "$BACKUP_DIR/"
    fi

    # 下载
    echo "下载中..."
    if curl -L -s -o "$TEMP_DIR/ui.zip" "$url"; then
        echo "解压中..."
        if unzip -q "$TEMP_DIR/ui.zip" -d "$TEMP_DIR"; then
            # 查找解压后的子目录 (github zip 通常包含一层文件夹)
            SUBDIR=$(find "$TEMP_DIR" -mindepth 1 -maxdepth 1 -type d | head -n 1)
            
            if [ -n "$SUBDIR" ]; then
                rm -rf "$UI_DIR"/*
                cp -r "$SUBDIR"/* "$UI_DIR/"
                echo -e "${GREEN}✓ $name 安装成功！${NC}"
                # 权限修复
                chown -R sing-box:sing-box "$UI_DIR" 2>/dev/null
            else
                echo -e "${RED}解压结构异常。${NC}"
                restore_backup
            fi
        else
            echo -e "${RED}解压失败。${NC}"
            restore_backup
        fi
    else
        echo -e "${RED}下载失败。${NC}"
        restore_backup
    fi
    
    # 清理
    rm -rf "$TEMP_DIR"
}

restore_backup() {
    echo -e "${CYAN}正在还原备份...${NC}"
    cp -r "$BACKUP_DIR"/* "$UI_DIR/" 2>/dev/null
}

# 3. 菜单
echo -e "${CYAN}=== Sing-box Web UI 管理 ===${NC}"
echo "1. 安装 Zashboard (推荐)"
echo "2. 安装 Metacubexd (功能全)"
echo "3. 安装 Yacd (经典)"
echo "0. 退出"

read -rp "请选择: " choice
case $choice in
    1) install_ui "$ZASHBOARD" "Zashboard" ;;
    2) install_ui "$METACUBEXD" "Metacubexd" ;;
    3) install_ui "$YACD" "Yacd" ;;
    *) exit 0 ;;
esac