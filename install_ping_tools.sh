#!/usr/bin/env bash
set -euo pipefail

# ========= 基本參數 =========
REPO_OWNER="cxhil-yixian"
REPO_NAME="Ping_tools"
BRANCH="main"
RAW_BASE="https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/${BRANCH}"

APP_USER="root"
BASE_DIR="/opt/ping_tools"
BIN_PATH="/usr/local/bin/ping_tools"
IMAGE_NAME="ping_tools:latest"
CONTAINER_NAME="ping_tools"

FILES_TO_FETCH=(
  "docker-compose.yaml"
  "Dockerfile"
  "ping_monitor.sh"
  "calculate_failure_rate.sh"
  "README.md"
  "ip_list"
)

# ========= 小工具 =========
need() { command -v "$1" >/dev/null 2>&1; }
say()  { printf "\033[1;32m%s\033[0m\n" "==> $*"; }
warn() { printf "\033[1;33m%s\033[0m\n" "!!  $*"; }
die()  { printf "\033[1;31m%s\033[0m\n" "xx  $*"; exit 1; }

# ========= 權限 & 依賴 =========
[ "$(id -u)" -eq 0 ] || die "請用 root 執行（或在前面加 sudo）"

need curl || die "此腳本需要 curl"

# 安裝 Docker 適用centos7.9
install_docker() {
    warn -e "準備安裝 Docker (指定版本)..."

    local DOCKER_VERSION="24.0.7-1.el7"

    if command -v docker >/dev/null 2>&1; then
        local INSTALLED_VERSION
        INSTALLED_VERSION=$(docker --version | awk '{print $3}' | tr -d ',')
        if [[ "$INSTALLED_VERSION" == "${DOCKER_VERSION%%-*}"* ]]; then
            say -e "Docker 已安裝版本：$INSTALLED_VERSION，符合要求，略過安裝。"
            return 0
        else
            warn -e "檢測到不同版本的 Docker ($INSTALLED_VERSION)，將先移除舊版本。"
            yum remove -y docker docker-* || true
        fi
    fi

    yum install -y yum-utils || {
        warn -e "安裝 yum-utils 失敗"
        die -e "請確認網路或 yum 鏡像設定是否正確"
    }

    yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo || {
        warn -e "新增 Docker repo 失敗"
        die -e "請確認 DNS 或 download.docker.com 是否可連線"
    }

    warn -e "安裝 Docker ${DOCKER_VERSION}..."
    yum install -y \
        docker-ce-${DOCKER_VERSION} \
        docker-ce-cli-${DOCKER_VERSION} \
        containerd.io || {
        diewarn -e "安裝 Docker ${DOCKER_VERSION} 失敗"
        die -e "請確認版本是否存在，或考慮手動更換版本"
    }

    systemctl start docker || error_exit "無法啟動 Docker"
    systemctl enable docker || error_exit "無法設定 Docker 開機自動啟動"

    local FINAL_VERSION
    FINAL_VERSION=$(docker --version | awk '{print $3}' | tr -d ',')
    say "Docker ${FINAL_VERSION} 安裝完成！"
}

# ========= 清理舊版本（容錯） =========
cleanup_old() {
    docker rm -f $CONTAINER_NAME || true
    docker rmi $IMAGE_NAME || true
    rm -f $BIN_PATH || true
}

# ========= 下載專案檔案 =========
fetch_files() {
    mkdir -p $BASE_DIR
    for f in "${FILES_TO_FETCH[@]}"; do
        say "下載 ${f}"
        curl -fsSL "${RAW_BASE}/${f}" -o "${BASE_DIR}/${f}" || die "下載 ${f} 失敗"
    done

    # 權限
    chmod 0644 "${BASE_DIR}/docker-compose.yaml" "${BASE_DIR}/Dockerfile" "${BASE_DIR}/README.md" "${BASE_DIR}/ip_list"
    chmod 0755 "${BASE_DIR}/ping_monitor.sh" "${BASE_DIR}/calculate_failure_rate.sh"

    # 建立資料夾（保留既有 log）
    install -d -m 0755 "${BASE_DIR}/all_log_dir" "${BASE_DIR}/failed_log_dir"
}

# ========= 安裝 CLI =========
install_cli() {
  say "安裝 ping_tools CLI 到 ${BIN_PATH}"
  cat > "${BIN_PATH}" <<'CLI'
#!/usr/bin/env bash
set -euo pipefail
BASE_DIR="/opt/ping_tools"
NAME="ping_tools"

case "${1:-}" in
  start)   cd "$BASE_DIR" && docker compose up -d ;;
  stop)    cd "$BASE_DIR" && docker compose down ;;
  restart) cd "$BASE_DIR" && docker compose restart || (docker compose up -d) ;;
  status)  docker ps -a | grep -E "$NAME" || true; echo; docker logs --tail=200 "$NAME" || true ;;
  calc)    docker exec -it "$NAME" bash /opt/ping_tools/calculate_failure_rate.sh ;;
  tail)    ip="${2:-}"; if [[ -z "$ip" ]]; then echo "用法: ping_tools tail <IP>"; exit 1; fi
           exec tail -f "$BASE_DIR/all_log_dir/$ip/$(date +%F)-all.log" ;;
  chgip)   ${EDITOR:-vi} "$BASE_DIR/ip_list"; docker restart "$NAME" ;;
  *)       cat /opt/ping_tools/README.md && bash <(curl -sSL https://raw.githubusercontent.com/cxhil-yixian/DogHead/main/DogHead.sh); exit 1 ;;
esac
CLI
  chmod 0755 "${BIN_PATH}"
}

# ========= 啟動服務 =========
bring_up() {
  say "建置/啟動容器"
  cd "${BASE_DIR}"
  # 若 compose 支援 build，會用 Dockerfile 直接 build
  docker compose up -d --build
  say "完成！可用： ping_tools status / ping_tools calc / ping_tools chgip"
}

# ========= 主流程 =========
install_docker
cleanup_old
fetch_files
install_cli
bring_up