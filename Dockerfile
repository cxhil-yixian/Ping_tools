# 使用較小的 Linux base image
FROM centos:7

# 建立目錄
RUN mkdir -p /opt/ping_tools

# 複製全部檔案進 container
COPY . /opt/ping_tools

# 授權所有腳本可執行
RUN chmod +x /opt/ping_tools/ping_monitor.sh \
    && chmod +x /opt/ping_tools/calculate_failure_rate.sh

# 容器啟動時，直接執行 ping_monitor.sh
CMD ["/opt/ping_tools/ping_monitor.sh"]
