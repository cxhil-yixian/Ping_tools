#!/bin/bash

# ping 參數
PING_COUNT=1
PING_TIMEOUT=1
PING_COMMAND="ping -c $PING_COUNT -W $PING_TIMEOUT"

# 基礎路徑
BASE_DIR="/opt/ping_tools"
FAILED_DIR="$BASE_DIR/failed_log_dir"
LOG_DIR="$BASE_DIR/all_log_dir"
CHANGE_IP_FILE="$BASE_DIR/change_ip.log"
IP_LIST_FILE="$BASE_DIR/ip_list"

# 建立基礎目錄
mkdir -p "$LOG_DIR" "$FAILED_DIR"

# 抓取所有 IP，過濾掉空白行
mapfile -t IP_ARRAY < <(grep -v '^[[:space:]]*$' "$IP_LIST_FILE")
IP_COUNT=${#IP_ARRAY[@]}

if [ "$IP_COUNT" -eq 0 ]; then
    echo "IP list is empty. Exiting."
    exit 1
fi

CURRENT_INDEX=0

# 收尾 function (可擴充做清理)
cleanup() {
    echo "[$(date "+%Y-%m-%d %H:%M:%S")] Script terminated."
    exit 0
}

# 捕捉 Ctrl+C
trap cleanup SIGINT

while true; do
    SEQ=1
    FAIL_COUNTER=0

    TARGET_IP="${IP_ARRAY[$CURRENT_INDEX]}"
    TARGET_IP="$(echo "$TARGET_IP" | tr -d '[:space:]')"

    if [ -z "$TARGET_IP" ]; then
        echo "[$(date "+%Y-%m-%d %H:%M:%S")] Empty IP encountered. Skipping."
        ((CURRENT_INDEX++))
        if [ "$CURRENT_INDEX" -ge "$IP_COUNT" ]; then
            CURRENT_INDEX=0
        fi
        continue
    fi

    echo "[$(date "+%Y-%m-%d %H:%M:%S")] Starting ping check for IP: $TARGET_IP"

    while [ "$FAIL_COUNTER" -lt 60 ]; do
        DATE=$(date +%F)
        TIME=$(date "+%Y-%m-%d %H:%M:%S")

        # IP 專屬目錄
        LOG_DIR_IP="$LOG_DIR/$TARGET_IP"
        FAILED_DIR_IP="$FAILED_DIR/$TARGET_IP"
        mkdir -p "$LOG_DIR_IP" "$FAILED_DIR_IP"

        DAILY_LOG="$LOG_DIR_IP/${DATE}-all.log"
        FAILED_LOG="$FAILED_DIR_IP/${DATE}-failed.log"

        # 執行 ping
        PING_OUTPUT=$($PING_COMMAND "$TARGET_IP" 2>&1)

        if echo "$PING_OUTPUT" | grep -q "bytes from"; then
            LINE=$(echo "$PING_OUTPUT" | grep "bytes from")

            # 擷取 time (毫秒) 整數部分
            TIME_MS=$(awk -F'time=' '{print $2}' <<< "$LINE" | awk '{print $1}' | cut -d'.' -f1)

            # 寫成功 log
            echo "[${SEQ}][$TIME] $LINE" >> "$DAILY_LOG"

            # 判斷 time_ms 是否為數字，且是否超過 200ms
            if [[ "$TIME_MS" =~ ^[0-9]+$ ]]; then
                if [ "$TIME_MS" -gt 200 ]; then
                    echo "[${SEQ}][$TIME] $LINE" >> "$FAILED_LOG"
                    ((FAIL_COUNTER++))
                else
                    FAIL_COUNTER=0
                fi
            else
                # 若抓不到 time 也算失敗
                echo "[${SEQ}][$TIME] Unable to parse ping time." >> "$FAILED_LOG"
                ((FAIL_COUNTER++))
            fi
        else
            # ping 不通
            echo "[${SEQ}][$TIME] Ping to $TARGET_IP failed." >> "$DAILY_LOG"
            echo "[${SEQ}][$TIME] Ping to $TARGET_IP failed." >> "$FAILED_LOG"
            ((FAIL_COUNTER++))
        fi

        ((SEQ++))
        sleep 1
    done

    echo "[$(date "+%Y-%m-%d %H:%M:%S")] IP $TARGET_IP failed 60 times, switching to next IP." >> "$CHANGE_IP_FILE"

    ((CURRENT_INDEX++))
    if [ "$CURRENT_INDEX" -ge "$IP_COUNT" ]; then
        CURRENT_INDEX=0
    fi
done
