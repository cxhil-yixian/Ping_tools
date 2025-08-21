#!/bin/bash

case "$1" in
    start)
        cd /opt/ping_tools && docker compose up -d
        ;;
    stop)
        cd /opt/ping_tools && docker compose down
        ;;
    restart)
        cd /opt/ping_tools && docker compose restart
        ;;
    status)
        docker ps -a | grep ping_tools && docker logs ping_tools
        ;;
    calc)
        docker exec -it ping_tools bash /opt/ping_tools/calculate_failure_rate.sh
        ;;
    cli)
        vi /usr/local/bin/ping_tools
        ;;
    chgip)
        vi /opt/ping_tools/china_ip_list && echo "等待配置中..." && docker restart ping_tools
        ;;
    *)
        cat /opt/ping_tools/README.md
        bash <(curl -sSL https://raw.githubusercontent.com/cxhil-yixian/DogHead/main/DogHead.sh)
        exit 1
        ;;
esac
