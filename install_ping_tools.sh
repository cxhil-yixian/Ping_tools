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

# 安裝 Docker / docker compose plugin（盡量通用）
install_docker() {
  if need docker && docker compose version >/dev/null 2>&1; then
    say "Docker 與 docker compose 已就緒"
    return
  fi

  say "安裝 Docker（會依發行版自動判斷）"
  if need apt-get; then
    apt-get update -y
    apt-get install -y ca-certificates curl gnupg lsb-release
    install -d -m 0755 /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/$(. /etc/os-release; echo "$ID")/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$(. /etc/os-release; echo "$ID") \
      $(. /etc/os-release; echo "$VERSION_CODENAME") stable" \
      > /etc/apt/sources.list.d/docker.list
    apt-get update -y
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    systemctl enable --now docker
  elif need dnf; then
    dnf -y install dnf-plugins-core
    dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo || true
    dnf -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    systemctl enable --now docker
  elif need yum; then
    yum install -y yum-utils
    yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo || true
    yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    systemctl enable --now docker
  elif need zypper; then
    zypper refresh
    zypper install -y docker
    systemctl enable --now docker
    # docker compose plugin 可能需另裝；若無則 fallback 用 docker compose v2 二進位
  elif need pacman; then
    pacman -Sy --noconfirm docker
    systemctl enable --now docker
  else
    warn "偵測不到常見套件管理器，嘗試繼續（系統需自備 docker 與 docker compose plugin）"
  fi

  if ! docker compose version >/dev/null 2>&1; then
    warn "找不到 docker compose plugin，嘗試安裝獨立 compose v2"
    curl -fsSL "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    ln -sf /usr/local/bin/docker-compose /usr/local/bin/docker-compose-v2 || true
  fi
}

# ========= 清理舊版本（容錯） =========
cleanup_old() {
  say "移除舊容器/映像與檔案（若存在）"
  docker stop "${CONTAINER_NAME}" >/dev/null 2>&1 || true
  docker rm   "${CONTAINER_NAME}" >/dev/null 2>&1 || true
  docker rmi  "${IMAGE_NAME}" >/dev/null 2>&1 || true

  rm -f "${BIN_PATH}" || true
  # 不主動刪 ${BASE_DIR} 以保留舊 log；只確保結構存在
}

# ========= 下載專案檔案 =========
fetch_files() {
  say "同步 GitHub 組態與腳本到 ${BASE_DIR}"
  install -d -m 0755 "${BASE_DIR}"
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
  *)       echo "用法: ping_tools { start | stop | restart | status | calc | tail <IP> | chgip }"; exit 1 ;;
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