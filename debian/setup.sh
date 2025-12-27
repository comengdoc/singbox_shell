#!/bin/bash

# --- 脚本设置 ---
set -eEuo pipefail
trap 'echo -e "\033[31m❌ 发生错误 (行 $LINENO)\033[0m" >&2; exit 1' ERR

# --- 样式定义 ---
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BOLD='\033[1m'
RESET='\033[0m'

# --- 变量 ---
DOMAIN=""
EMAIL=""
ACME_INSTALL_PATH="$HOME/.acme.sh"
CERT_KEY_DIR="" 

# 检查 Root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}请使用 root 权限运行。${RESET}"
    exit 1
fi

# 1. 获取输入
echo -e "${BOLD}=== SSL 证书一键申请 (ACME.sh) ===${RESET}"
read -r -p "请输入域名: " DOMAIN
read -r -p "请输入邮箱: " EMAIL

if [[ -z "$DOMAIN" || -z "$EMAIL" ]]; then
    echo -e "${RED}输入不能为空。${RESET}"
    exit 1
fi

# 2. 安装依赖
echo -e "${YELLOW}正在检查依赖...${RESET}"
if command -v apt-get >/dev/null; then
    apt-get update -qq
    apt-get install -y curl socat cron ufw acl
elif command -v yum >/dev/null; then
    yum install -y curl socat cronie firewalld acl
fi

# 3. 开放端口 (80 端口用于验证)
echo -e "${YELLOW}正在配置防火墙放行 80/443...${RESET}"
if command -v ufw >/dev/null && ufw status | grep -q active; then
    ufw allow 80/tcp
    ufw allow 443/tcp
elif command -v firewall-cmd >/dev/null && systemctl is-active --quiet firewalld; then
    firewall-cmd --add-port=80/tcp --permanent
    firewall-cmd --add-port=443/tcp --permanent
    firewall-cmd --reload
fi

# 4. 安装/调用 ACME.sh
if [ ! -f "$ACME_INSTALL_PATH/acme.sh" ]; then
    echo -e "${YELLOW}正在安装 acme.sh...${RESET}"
    curl https://get.acme.sh | sh -s email="$EMAIL"
fi
ACME_CMD="$ACME_INSTALL_PATH/acme.sh"

# 5. 申请证书
echo -e "${YELLOW}正在申请证书 (Standalone 模式)...${RESET}"
echo "如果有 Web 服务占用 80 端口，将尝试暂停它。"

# 尝试停止常见的 Web 服务以释放 80 端口
systemctl stop nginx 2>/dev/null || true
systemctl stop apache2 2>/dev/null || true

"$ACME_CMD" --issue --standalone -d "$DOMAIN" --force

# 6. 安装证书到 Sing-box 目录
CERT_KEY_DIR="/etc/sing-box/cert"
mkdir -p "$CERT_KEY_DIR"

echo -e "${YELLOW}正在安装证书到 $CERT_KEY_DIR ...${RESET}"

"$ACME_CMD" --installcert -d "$DOMAIN" \
    --key-file       "${CERT_KEY_DIR}/private.key" \
    --fullchain-file "${CERT_KEY_DIR}/public.crt" \
    --reloadcmd      "systemctl restart sing-box"

# 7. 关键步骤：修复权限
# 因为 sing-box 以 sing-box 用户运行，必须让它能读取 root 申请的证书
echo -e "${YELLOW}正在修复证书权限...${RESET}"

# 方法A: 更改所有者
chown -R sing-box:sing-box "$CERT_KEY_DIR"
chmod 750 "$CERT_KEY_DIR"
chmod 640 "${CERT_KEY_DIR}/private.key"
chmod 644 "${CERT_KEY_DIR}/public.crt"

echo -e "${GREEN}✅ 证书申请并安装成功！${RESET}"
echo -e "公钥路径: ${BOLD}${CERT_KEY_DIR}/public.crt${RESET}"
echo -e "私钥路径: ${BOLD}${CERT_KEY_DIR}/private.key${RESET}"
echo -e "权限已修正，Sing-box 可直接读取。"

# 尝试恢复 Web 服务 (可选)
# systemctl start nginx 2>/dev/null || true