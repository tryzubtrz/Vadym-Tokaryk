#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMUX_BIN="${TMUX_BIN:-/exec-daemon/tmux}"
CONF="${TMUX_CONF:-/exec-daemon/tmux.portal.conf}"
t() { "$TMUX_BIN" -f "$CONF" "$@"; }

stop_one() {
  local name="$1"
  t has-session -t "=$name" 2>/dev/null || return 0
  t send-keys -t "$name:0.0" "end" C-m 2>/dev/null || true
  t send-keys -t "$name:0.0" "stop" C-m 2>/dev/null || true
  for _ in $(seq 1 25); do
    t has-session -t "=$name" 2>/dev/null || return 0
    sleep 1
  done
  t kill-session -t "$name" 2>/dev/null || true
}

echo "[FunnyNetwork] Stopping..."
stop_one fn-proxy || true
if [[ -f "$ROOT/runtime/modes.list" ]]; then
  while read -r mode _port _mem; do
    [[ -z "${mode:-}" ]] && continue
    stop_one "fn-$mode" || true
  done < "$ROOT/runtime/modes.list"
fi
stop_one fn-tunnel || true
pkill -f 'bore-tunnel local 25565' 2>/dev/null || true
pkill -f 'purpur.jar' 2>/dev/null || true
pkill -f 'velocity.jar' 2>/dev/null || true
sleep 2
echo "[FunnyNetwork] Stopped."
