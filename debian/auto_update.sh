#!/bin/bash

CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

MANUAL_FILE="/etc/sing-box/manual.conf"
UPDATE_SCRIPT="/etc/sing-box/update-singbox.sh"

# 0. 前置检查
if [ ! -f "$MANUAL_FILE" ]; then
    echo -e "${RED}错误: 未找到订阅配置文件 ($MANUAL_FILE)。${NC}"
    echo -e "${YELLOW}请先在主菜单执行 [手动更新订阅] 或 [导入订阅] 后再设置自动更新。${NC}"
    exit 1
fi

# --- 生成执行脚本 ---
# 注意：这里使用 EOF 而不是 'EOF'，以便变量在生成时解析。
# 但对于脚本内部需要运行时解析的变量（如 $FULL_URL），我们需要转义 \$
cat > "$UPDATE_SCRIPT" <<EOF
#!/bin/bash
# 自动生成的 Sing-box 更新脚本
# 生成时间: $(date)

LOG_FILE="/var/log/sing-box-update.log"

log() {
    echo "[\$(date '+%Y-%m-%d %H:%M:%S')] \$1" >> "\$LOG_FILE"
}

# 读取配置
BACKEND_URL=\$(grep BACKEND_URL $MANUAL_FILE | cut -d'=' -f2-)
SUBSCRIPTION_URL=\$(grep SUBSCRIPTION_URL $MANUAL_FILE | cut -d'=' -f2-)
TEMPLATE_URL=\$(grep TEMPLATE_URL $MANUAL_FILE | cut -d'=' -f2-)

if [ -z "\$BACKEND_URL" ] || [ -z "\$SUBSCRIPTION_URL" ]; then
    log "错误: 配置文件参数缺失，跳过更新。"
    exit 1
fi

FULL_URL="\${BACKEND_URL}/config/\${SUBSCRIPTION_URL}&file=\${TEMPLATE_URL}"

# 备份
[ -f "/etc/sing-box/config.json" ] && cp /etc/sing-box/config.json /etc/sing-box/config.json.backup

log "开始下载新配置..."
if curl -s -L --connect-timeout 15 --max-time 60 "\$FULL_URL" -o /etc/sing-box/config.json; then
    if sing-box check -c /etc/sing-box/config.json >/dev/null 2>&1; then
        log "配置验证成功，重启服务。"
        systemctl restart sing-box
    else
        log "新配置验证失败，回滚备份。"
        [ -f "/etc/sing-box/config.json.backup" ] && cp /etc/sing-box/config.json.backup /etc/sing-box/config.json
    fi
else
    log "下载失败，回滚备份。"
    [ -f "/etc/sing-box/config.json.backup" ] && cp /etc/sing-box/config.json.backup /etc/sing-box/config.json
fi
EOF

chmod +x "$UPDATE_SCRIPT"

# --- 菜单逻辑 ---
while true; do
    echo -e "\n${CYAN}=== 自动更新配置 ===${NC}"
    echo "1. 设置/修改 自动更新频率"
    echo "2. 关闭 自动更新"
    echo "0. 返回"
    read -rp "请选择: " menu_choice

    case $menu_choice in
        1)
            read -rp "请输入更新间隔 (小时, 1-23): " interval
            if [[ ! "$interval" =~ ^[0-9]+$ ]] || [ "$interval" -lt 1 ] || [ "$interval" -gt 23 ]; then
                echo -e "${RED}输入无效，请输入 1-23 之间的数字。${NC}"
                continue
            fi

            # 安全处理 crontab
            current_cron=$(crontab -l 2>/dev/null)
            # 移除旧任务
            new_cron=$(echo "$current_cron" | grep -v "$UPDATE_SCRIPT")
            
            # 添加新任务 (0分 */n 小时)
            echo -e "$new_cron\n0 */$interval * * * $UPDATE_SCRIPT" | crontab -
            
            echo -e "${GREEN}✓ 已设置：每 $interval 小时自动检查更新。${NC}"
            break
            ;;
        2)
            crontab -l 2>/dev/null | grep -v "$UPDATE_SCRIPT" | crontab -
            echo -e "${YELLOW}✓ 自动更新任务已移除。${NC}"
            break
            ;;
        0)
            exit 0
            ;;
        *)
            echo -e "${RED}无效输入。${NC}"
            ;;
    esac
done