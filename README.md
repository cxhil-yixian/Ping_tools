# Ping_tools

使用方法 : ping_tools { start | stop | restart | calc | status | cli | chgip }

1. 使用方式為 ping_tools start 即可啟動(預設啟動)監控程式，監控目標為 ip_list 內的 IP

2. 終止請使用 ping_tools stop

3. 計算失敗率請使用 ping_tools calc

4. 查看目前監控容器狀態或是啟動失敗請使用 ping_tools status

5. 更改 IP 列表請使用 ping_tools chgip

6. all_log_dir 放置全部輸出，failed_log_dir 放置錯誤輸出

7. 若連續失敗達 60 次就換下一個 IP，直到第最後一個也失敗再從頭開始，change_ip.log 記錄切換IP的log，希望不要有內容

8. 卸載請使用 ping_tools rm

---------------------------------------------------------------------------------------------------------------------------
!!! 只適用於CentOS 7.9 !!!

