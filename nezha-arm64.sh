#!/bin/sh
# nezha-arm64.sh
# 一键安装/管理 Nezha Agent (ARM64 / AARCH64)
# 用法：
#   CLIENT_SECRET=xxx ./nezha-arm64.sh [install|restart|status|uninstall]
# 若不指定命令，则默认执行 install

set -e

NEZHA_DIR="/etc/nezha"
INIT_SCRIPT="/etc/init.d/nezha-service"
BINARY_URL="https://r2.354770.xyz/nezha-agent-arm64-linux"
SERVER="0.zmcloud.eu.org:8088"
BINARY_NAME="nezha-agent"

log() { echo "[nezha] $1"; }
err() { echo "[nezha][ERROR] $1" >&2; exit 1; }

ensure_cmd() {
  for cmd in "$@"; do
    command -v "$cmd" >/dev/null 2>&1 || err "缺少命令: $cmd"
  done
}

check_arch() {
  arch="$(uname -m)"
  case "$arch" in
    aarch64|arm64)
      return 0 ;;
    *)
      err "仅支持 aarch64 / arm64 架构，当前为: $arch" ;;
  esac
}

write_config() {
  client_secret="$1"
  uuid="$(cat /proc/sys/kernel/random/uuid)"
  mkdir -p "$NEZHA_DIR"
  cat > "$NEZHA_DIR/config.yml" <<-EOF
client_secret: ${client_secret}
debug: false
disable_auto_update: false
disable_command_execute: false
disable_force_update: false
disable_nat: false
disable_send_query: false
gpu: false
insecure_tls: false
ip_report_period: 1800
report_delay: 1
server: ${SERVER}
skip_connection_count: false
skip_procs_count: false
temperature: false
tls: false
use_gitee_to_upgrade: false
use_ipv6_country_code: false
uuid: ${uuid}
EOF
  chmod 600 "$NEZHA_DIR/config.yml"
  log "配置文件已生成: $NEZHA_DIR/config.yml"
}

write_init_script() {
  cat > "$INIT_SCRIPT" <<'EOF'
#!/bin/sh /etc/rc.common
# nezha-service
START=99
USE_PROCD=1

start_service() {
    procd_open_instance
    procd_set_param command /etc/nezha/nezha-agent -c /etc/nezha/config.yml
    procd_set_param respawn
    procd_close_instance
}

stop_service() {
    killall nezha-agent 2>/dev/null
}

restart() {
    stop
    sleep 2
    start
}
EOF
  chmod +x "$INIT_SCRIPT"
  log "服务脚本已创建: $INIT_SCRIPT"
}

install_agent() {
  ensure_cmd wget chmod
  check_arch
  CLIENT_SECRET="${CLIENT_SECRET:-}"

  if [ -z "$CLIENT_SECRET" ]; then
    printf "请输入 CLIENT_SECRET: "
    read -r CLIENT_SECRET
  fi
  [ -z "$CLIENT_SECRET" ] && err "CLIENT_SECRET 不能为空"

  mkdir -p "$NEZHA_DIR"
  cd "$NEZHA_DIR"

  log "下载 nezha-agent (arm64)..."
  wget -q -O "$BINARY_NAME" "$BINARY_URL" || err "下载失败，请检查网络或下载地址"
  chmod +x "$BINARY_NAME"

  write_config "$CLIENT_SECRET"
  write_init_script

  /etc/init.d/nezha-service enable
  /etc/init.d/nezha-service start
  log "安装完成 ✅"
  log "查看状态: ./nezha-arm64.sh status"
}

status_agent() {
  if pgrep -f "$NEZHA_DIR/$BINARY_NAME" >/dev/null 2>&1; then
    echo "nezha-agent 正在运行："
    ps | grep "$BINARY_NAME" | grep -v grep
  else
    echo "nezha-agent 未运行"
  fi
}

restart_agent() {
  /etc/init.d/nezha-service restart || {
    killall "$BINARY_NAME" 2>/dev/null || true
    "$NEZHA_DIR/$BINARY_NAME" -c "$NEZHA_DIR/config.yml" &
  }
  log "服务已重启"
  status_agent
}

uninstall_agent() {
  echo "确认卸载 nezha-agent？(y/N): "
  read -r confirm
  case "$confirm" in
    y|Y)
      /etc/init.d/nezha-service stop || true
      /etc/init.d/nezha-service disable || true
      rm -f "$INIT_SCRIPT"
      rm -rf "$NEZHA_DIR"
      log "已卸载 nezha-agent 并删除相关文件"
      ;;
    *) log "已取消卸载" ;;
  esac
}

ACTION="${1:-install}"
case "$ACTION" in
  install) install_agent ;;
  status) status_agent ;;
  restart) restart_agent ;;
  uninstall) uninstall_agent ;;
  *)
    echo "用法: CLIENT_SECRET=xxx $0 [install|restart|status|uninstall]"
    ;;
esac
