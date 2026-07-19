#!/usr/bin/env bash
# Статус мережі MineLegacy
set -euo pipefail
source "$(dirname "$0")/common.sh"

check() {
  local name="$1"
  local pidfile="$ROOT/run/${name}.pid"
  if [[ -f "$pidfile" ]] && kill -0 "$(cat "$pidfile")" 2>/dev/null; then
    echo -e "  \033[32m●\033[0m $name (pid $(cat "$pidfile"))"
  else
    echo -e "  \033[31m○\033[0m $name (не запущено)"
    rm -f "$pidfile" 2>/dev/null || true
  fi
}

echo "Статус мережі MineLegacy:"
check velocity
for s in "${SERVERS[@]}"; do
  check "$s"
done

echo
echo "Відкриті порти Minecraft:"
ss -tlnp 2>/dev/null | grep -E '2556[5-9]|2557[01]' || netstat -tlnp 2>/dev/null | grep -E '2556' || true
