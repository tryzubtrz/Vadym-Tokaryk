#!/usr/bin/env bash
# First-boot worlds + force Velocity forwarding in paper-global.yml
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RT="$ROOT/runtime"
TMUX_BIN="${TMUX_BIN:-/exec-daemon/tmux}"
CONF="${TMUX_CONF:-/exec-daemon/tmux.portal.conf}"
JAVA_BIN="${JAVA_BIN:-java}"
SECRET="$(tr -d '\n' < "$RT/secrets/forwarding.secret")"
t() { "$TMUX_BIN" -f "$CONF" "$@"; }
t start-server 2>/dev/null || true

ensure() { t has-session -t "=$1" 2>/dev/null || t new-session -d -s "$1" -c "$2" -- bash -l; }

patch_velocity() {
  local pg="$1"
  python3 - "$pg" "$SECRET" <<'PY'
import sys,re
p,secret=sys.argv[1],sys.argv[2]
from pathlib import Path
path=Path(p)
if not path.exists():
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(f"proxies:\n  velocity:\n    enabled: true\n    online-mode: false\n    secret: '{secret}'\n")
    print('created',p); raise SystemExit
t=path.read_text()
if "velocity:" in t:
    t2=re.sub(r"  velocity:\n    enabled:.*\n    online-mode:.*\n    secret:.*",
              f"  velocity:\n    enabled: true\n    online-mode: false\n    secret: '{secret}'",
              t, count=1)
else:
    t2=t.rstrip()+"\nproxies:\n  velocity:\n    enabled: true\n    online-mode: false\n    secret: '%s'\n"%secret
path.write_text(t2)
print('patched',p)
PY
}

while read -r mode port mem; do
  [[ -z "${mode:-}" ]] && continue
  dir="$RT/servers/$mode"
  marker="$dir/.prepared"
  if [[ -f "$marker" && -d "$dir/world" ]]; then
    echo "skip $mode (already prepared)"
    patch_velocity "$dir/config/paper-global.yml"
    continue
  fi
  echo "=== first boot $mode ==="
  ensure "prep-$mode" "$dir"
  t send-keys -t "prep-$mode:0.0" \
    "$JAVA_BIN -Xms${mem} -Xmx${mem} -XX:+UseG1GC -jar purpur.jar --nogui" C-m
  ok=0
  for i in $(seq 1 100); do
    if t capture-pane -t "prep-$mode:0.0" -p -S -80 2>/dev/null | grep -qE 'Done \([0-9]'; then
      ok=1; break
    fi
    sleep 2
  done
  if [[ "$ok" != "1" ]]; then
    echo "FAIL first boot $mode"
    t capture-pane -t "prep-$mode:0.0" -p | tail -25
    exit 1
  fi
  t send-keys -t "prep-$mode:0.0" 'stop' C-m
  for i in $(seq 1 40); do
    t has-session -t "=prep-$mode" 2>/dev/null || break
    # process ended when session still exists but idle — kill after stop settles
    if t capture-pane -t "prep-$mode:0.0" -p | tail -3 | grep -qE '\$|#|>'; then
      sleep 2
      break
    fi
    sleep 1
  done
  t kill-session -t "prep-$mode" 2>/dev/null || true
  patch_velocity "$dir/config/paper-global.yml"
  date -Is > "$marker"
  echo "prepared $mode"
  free -m | awk '/Mem:/{printf "RAM avail %sMB\n",$7}'
done < "$RT/modes.list"

echo "[FunnyNetwork] First-boot complete. Run bin/start-all.sh"
