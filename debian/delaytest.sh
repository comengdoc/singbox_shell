#!/bin/bash

# --- 样式定义 ---
CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

LOG_FILE="latency_log.txt"

# 0. 依赖检查
if ! command -v bc &> /dev/null; then
    echo -e "${YELLOW}正在安装必要依赖: bc ...${NC}"
    sudo apt-get update -qq && sudo apt-get install -y bc
fi

# --- 核心函数 ---
run_test() {
    local TARGET="$1"
    # 补全协议
    [[ "$TARGET" != http* ]] && TARGET="https://$TARGET"
    
    echo -e "${CYAN}正在测试目标: ${BOLD}$TARGET${NC}"
    
    local total_time=0
    local success_count=0
    local max_time=0
    local min_time=9999
    
    for i in {1..5}; do
        # 增加随机参数防止缓存
        local url="${TARGET}?_t=$(date +%s%N)"
        
        # 获取连接数据
        result=$(curl -s -w "%{time_connect},%{time_total},%{http_code}" -o /dev/null --connect-timeout 5 "$url")
        
        # 解析结果
        IFS=',' read -r t_conn t_total http_code <<< "$result"
        
        if [ "$http_code" -eq 000 ] || [ -z "$t_total" ]; then
            printf "  [%d/5] ${RED}超时或连接失败${NC}\n" "$i"
            continue
        fi

        # 转换为毫秒 (利用 awk)
        local ms_total=$(awk "BEGIN {printf \"%.0f\", $t_total * 1000}")
        local ms_conn=$(awk "BEGIN {printf \"%.0f\", $t_conn * 1000}")
        
        printf "  [%d/5] 延迟: ${GREEN}%4s ms${NC} (握手: %s ms)\n" "$i" "$ms_total" "$ms_conn"
        
        # 统计
        total_time=$((total_time + ms_total))
        success_count=$((success_count + 1))
        [ "$ms_total" -gt "$max_time" ] && max_time=$ms_total
        [ "$ms_total" -lt "$min_time" ] && min_time=$ms_total
        
        # 记录日志
        echo "$(date '+%F %T'),$TARGET,$ms_total" >> "$LOG_FILE"
    done
    
    echo "----------------------------------------"
    if [ "$success_count" -gt 0 ]; then
        local avg=$(awk "BEGIN {printf \"%.1f\", $total_time / $success_count}")
        echo -e "📊 统计: 平均 ${YELLOW}${avg}ms${NC} | 最快 ${GREEN}${min_time}ms${NC} | 最慢 ${RED}${max_time}ms${NC}"
        # 返回平均值给调用者
        echo "$avg" > /tmp/last_delay_result
    else
        echo -e "${RED}所有测试均失败。${NC}"
        echo "0" > /tmp/last_delay_result
    fi
}

run_batch_test() {
    local targets=("www.google.com" "www.github.com" "www.cloudflare.com" "www.youtube.com" "www.baidu.com")
    echo -e "${PURPLE}=== 批量基准测试 ===${NC}"
    
    printf "%-20s %-10s\n" "目标" "平均延迟"
    echo "--------------------------------"
    
    for host in "${targets[@]}"; do
        # 运行测试但隐藏详细输出，只看结果
        run_test "$host" > /dev/null
        local avg=$(cat /tmp/last_delay_result)
        
        local color=$GREEN
        if (( $(echo "$avg > 200" | bc -l) )); then color=$YELLOW; fi
        if (( $(echo "$avg > 1000" | bc -l) )) || [ "$avg" == "0" ]; then color=$RED; fi
        
        printf "%-20s ${color}%-10s${NC}\n" "$host" "${avg} ms"
    done
    
    read -rp "测试完成，按回车返回..."
}

# --- 菜单 ---
while true; do
    clear
    echo -e "${CYAN}=== 网络延迟真实测试 ===${NC}"
    echo "1. 测试 Google"
    echo "2. 测试 GitHub"
    echo "3. 测试 Cloudflare"
    echo "4. 批量测试常用站点 (Benchmark)"
    echo "5. 手动输入网址"
    echo "0. 返回"
    read -rp "选择: " choice
    
    case $choice in
        1) run_test "www.google.com"; read -rp "按回车继续..." ;;
        2) run_test "www.github.com"; read -rp "按回车继续..." ;;
        3) run_test "www.cloudflare.com"; read -rp "按回车继续..." ;;
        4) run_batch_test ;;
        5) 
           read -rp "请输入域名 (例如 www.bing.com): " custom
           [ -n "$custom" ] && run_test "$custom"
           read -rp "按回车继续..."
           ;;
        0) exit 0 ;;
        *) echo "无效选择" ;;
    esac
done