#!/bin/bash

set -e

# 刪除舊資料
echo "---- 刪除舊資料 ----"
rm -rf /opt/ping_tools || true
rm /usr/local/bin/ping_tools || true
docker stop ping_tools && docker rm ping_tools
docker rmi ping_tools || true
echo -e "\t\033[1m\033[32m 舊資料已刪除 \033[0m"

# 安裝 docker 環境
echo
echo "---- 安裝 docker 環境 ----"
mkdir -p /opt/ping_tools
mv ./ping_tools.tar /opt/ping_tools/
mv ./docker-compose.yaml /opt/ping_tools/
mv ./ip_list /opt/ping_tools/
mkdir -p /opt/ping_tools/ping_tools_data/all_log_dir
mkdir -p /opt/ping_tools/ping_tools_data/failed_log_dir
docker load -i /opt/ping_tools/ping_tools.tar
echo -e "\t\033[1m\033[32m docker 環境 已安裝 \033[0m"

# 安裝 ping_tools CLI
echo
echo "---- 安裝 ping_tools CLI ----"
cat ./create_ping_tools_cli_input > /usr/local/bin/ping_tools
chmod +x /usr/local/bin/ping_tools
echo -e "\t\033[1m\033[32m ping_tools CLI 已安裝 \033[0m"

# 測試 ping_tools CLI
echo
echo "可以執行以下指令測試 ping_tools CLI："
echo
echo  -e "\t\033[1m\033[32m ping_tools \033[0m"
