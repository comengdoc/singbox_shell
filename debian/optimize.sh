#!/bin/bash
set -e

# --- 样式定义 ---
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${CYAN}开始系统网络优化...${NC}"

# 1. 时间同步 (修复版)
echo "正在检查时间同步服务..."
if ! command -v chronyd >/dev/null 2>&1; then
    echo "安装 Chrony 时间同步服务..."
    apt-get update && apt-get install -y chrony
fi

# 修复核心逻辑：清理错误的 systemd 链接文件并启用正确的服务名
# 尝试停止服务，忽略错误
systemctl stop chronyd 2>/dev/null || true
systemctl stop chrony 2>/dev/null || true

# 如果存在导致报错的链接文件，强制删除
if [ -L "/etc/systemd/system/chronyd.service" ]; then
    echo "清理旧的 chronyd 服务链接..."
    rm -f /etc/systemd/system/chronyd.service
    systemctl daemon-reload
fi

# 启用正确的服务名 'chrony' (去掉 d)
systemctl unmask chrony >/dev/null 2>&1 || true
systemctl enable chrony
systemctl restart chrony

timedatectl set-timezone Asia/Shanghai || true
echo -e "${GREEN}✓ 时间同步已配置 (服务名: chrony)${NC}"

# 2. 内核参数优化 (Sysctl)
# 使用单独的文件，防止覆盖系统原有配置
SYSCTL_FILE="/etc/sysctl.d/99-singbox-tuning.conf"

cat > "$SYSCTL_FILE" << EOF
# --- Sing-box Network Tuning ---
# 内存管理
vm.swappiness = 10
vm.dirty_ratio = 10
vm.dirty_background_ratio = 5

# 最大文件打开数
fs.file-max = 1048576

# 网络核心
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 65536
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864

# TCP 缓冲区
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 16384 67108864

# TCP 连接管理
net.ipv4.tcp_max_syn_backlog = 65536
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_keepalive_probes = 3

# 拥塞控制 (BBR)
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr

# 开启转发 (关键)
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
EOF

echo -e "${GREEN}✓ 内核参数文件已创建 ($SYSCTL_FILE)${NC}"
# 重新加载 sysctl，忽略可能的 ipv6 错误（如果系统禁用了ipv6）
sysctl --system > /dev/null 2>&1 || echo -e "${YELLOW}! 内核参数加载完成 (忽略部分不支持的参数)${NC}"
echo -e "${GREEN}✓ 内核参数已应用${NC}"

# 3. 资源限制 (Limits)
# 同样使用模块化文件
LIMITS_FILE="/etc/security/limits.d/99-singbox.conf"

cat > "$LIMITS_FILE" << EOF
* soft nofile 1048576
* hard nofile 1048576
* soft nproc 65535
* hard nproc 65535
root soft nofile 1048576
root hard nofile 1048576
EOF

echo -e "${GREEN}✓ 资源限制文件已创建 ($LIMITS_FILE)${NC}"

# 4. 实时应用 limits (仅对当前 shell 有效，重启后永久生效)
ulimit -n 1048576 2>/dev/null || true

echo -e "${CYAN}优化完成！建议重启系统以确保所有设置完全生效。${NC}"