#!/usr/bin/env bash
# Зупинка мережі Тризуб
set -euo pipefail
source "$(dirname "$0")/common.sh"

stop_one() {
  local name="$1"
  local pidfile="$ROOT/run/${name}.pid"
  if [[ ! -f "$pidfile" ]]; then
    return
  fi
  local pid
  pid=$(cat "$pidfile")
  if kill -0 "$pid" 2>/dev/null; then
    log "Зупинка $name (pid $pid)..."
    kill "$pid" 2>/dev/null || true
    # м'яке очікування
    for _ in $(seq 1 30); do
      kill -0 "$pid" 2>/dev/null || break
      sleep 1
    done
    if kill -0 "$pid" 2>/dev/null; then
      log "Примусова зупинка $name"
      kill -9 "$pid" 2>/dev/null || true
    fi
  fi
  rm -f "$pidfile"
}

# Спочатку проксі, потім бекенди
stop_one velocity
for s in "${SERVERS[@]}"; do
  stop_one "$s"
done

log "Усі сервери зупинено."
