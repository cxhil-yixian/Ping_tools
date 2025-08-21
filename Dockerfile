# 使用 CentOS 7（符合原專案環境）
FROM centos:7

# 安裝必須套件
RUN yum install -y iputils bash coreutils procps-ng bc && yum clean all

# 建立目錄
RUN mkdir -p /opt/ping_tools

# 複製所有檔案
COPY . /opt/ping_tools

# 權限
RUN chmod +x /opt/ping_tools/ping_monitor.sh \
    /opt/ping_tools/calculate_failure_rate.sh && \
    mkdir -p /opt/ping_tools/all_log_dir /opt/ping_tools/failed_log_dir

WORKDIR /opt/ping_tools

# 預設執行監控程式
ENTRYPOINT ["/opt/ping_tools/ping_monitor.sh"]
