#!/bin/bash

# 基礎路徑
BASE_DIR="/opt/ping_tools"
ALL_LOG_DIR="$BASE_DIR/all_log_dir"
FAILED_LOG_DIR="$BASE_DIR/failed_log_dir"

# 總計
TOTAL_ALL=0
TOTAL_FAILED=0

echo
echo -e "IP地址\t\t日期\t\t當天加總\t當天失敗加總\t當天掉線率"

# 先掃描所有 IP 資料夾
for ip_dir in "$ALL_LOG_DIR"/*; do
    [ -d "$ip_dir" ] || continue

    IP=$(basename "$ip_dir")

    # 再掃該 IP 下所有 -all.log 檔
    for all_log in "$ip_dir"/*-all.log; do
        [ -f "$all_log" ] || continue

        # 擷取日期
        date=$(basename "$all_log" | cut -d'-' -f1-3)

        # 計算 all 次數
        all_count=$(wc -l < "$all_log" | awk '{print $1}')

        # 對應的 failed log
        failed_log="$FAILED_LOG_DIR/$IP/${date}-failed.log"
        if [ -f "$failed_log" ]; then
            failed_count=$(wc -l < "$failed_log" | awk '{print $1}')
        else
            failed_count=0
        fi

        # 掉線率計算
        if [ "$all_count" -ne 0 ]; then
            failure_rate=$(echo "scale=6; $failed_count * 100 / $all_count" | bc)
            if (( $(echo "$failure_rate == 0" | bc -l) )); then
                [ "$failed_count" -gt 0 ] && failure_rate=0.0001
            fi
        else
            failure_rate=0
        fi

        printf "%s\t%s\t%d\t\t%d\t\t%.4f%%\n" "$IP" "$date" "$all_count" "$failed_count" "$failure_rate"

        # 累加總計
        TOTAL_ALL=$((TOTAL_ALL + all_count))
        TOTAL_FAILED=$((TOTAL_FAILED + failed_count))
    done
done

# 總掉線率
if [ "$TOTAL_ALL" -ne 0 ]; then
    TOTAL_RATE=$(echo "scale=6; $TOTAL_FAILED * 100 / $TOTAL_ALL" | bc)
    if (( $(echo "$TOTAL_RATE == 0" | bc -l) )); then
        [ "$TOTAL_FAILED" -gt 0 ] && TOTAL_RATE=0.0001
    fi
else
    TOTAL_RATE=0
fi

echo
echo -e "所有加總\t所有失敗加總\t總掉線率"
printf "%d\t\t%d\t\t%.4f%%\n" "$TOTAL_ALL" "$TOTAL_FAILED" "$TOTAL_RATE"
echo
