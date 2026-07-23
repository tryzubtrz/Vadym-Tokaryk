#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RT="$ROOT/runtime"
TMUX_BIN="${TMUX_BIN:-/exec-daemon/tmux}"
CONF="${TMUX_CONF:-/exec-daemon/tmux.portal.conf}"
JAVA_BIN="${JAVA_BIN:-java}"
t() { "$TMUX_BIN" -f "$CONF" "$@"; }

t start-server 2>/dev/null || true

ensure() {
  local name="$1" dir="$2"
  t has-session -t "=$name" 2>/dev/null || t new-session -d -s "$name" -c "$dir" -- bash -l
}

wait_done() {
  local name="$1" tries="${2:-90}"
  for i in $(seq 1 "$tries"); do
    if t capture-pane -t "$name:0.0" -p -S -120 2>/dev/null | grep -qE 'Done \([0-9]|Listening on'; then
      echo "  ✓ $name ($i)"
      return 0
    fi
    if t capture-pane -t "$name:0.0" -p -S -40 2>/dev/null | grep -qiE 'OutOfMemory|FAILED TO BIND|UnsupportedClassVersion'; then
      echo "  ✗ $name crashed:"; t capture-pane -t "$name:0.0" -p | tail -20
      return 1
    fi
    sleep 2
  done
  echo "  ✗ $name timeout"; t capture-pane -t "$name:0.0" -p | tail -15
  return 1
}

echo "[FunnyNetwork] Starting mode servers (sequential)..."
while read -r mode port mem; do
  [[ -z "${mode:-}" ]] && continue
  dir="$RT/servers/$mode"
  ensure "fn-$mode" "$dir"
  echo ">> $mode :$port ($mem)"
  t send-keys -t "fn-$mode:0.0" C-c 2>/dev/null || true
  sleep 0.2
  t send-keys -t "fn-$mode:0.0" \
    "$JAVA_BIN -Xms${mem} -Xmx${mem} -XX:+UseG1GC -XX:MaxGCPauseMillis=200 -jar purpur.jar --nogui" C-m
  wait_done "fn-$mode" 100
  free -m | awk '/Mem:/{printf "  RAM avail: %sMB\n",$7}'
done < "$RT/modes.list"

# Restart backends that needed paper patch after first gen (only if just patched and were first boot)
# Safer: always quick-restart each once if velocity was false — skipped if already correct.

echo "[FunnyNetwork] Starting Velocity..."
ensure fn-proxy "$RT/proxy"
t send-keys -t "fn-proxy:0.0" \
  "$JAVA_BIN -Xms512M -Xmx768M -XX:+UseG1GC -jar velocity.jar" C-m
wait_done fn-proxy 40

echo "[FunnyNetwork] Bootstrap permissions..."
sleep 1
for c in \
  'lp group default permission set essentials.spawn true' \
  'lp group default permission set essentials.kits.starter true' \
  'lp group default permission set deluxemenus.open true' \
  'lp group default permission set playerpoints.me true' \
  'gamerule doDaylightCycle false' \
  'gamerule doWeatherCycle false' \
  'time set day' \
  'difficulty peaceful' \
  'fill -10 64 -10 10 64 10 stone' \
  'setworldspawn 0 65 0'; do
  t send-keys -t "fn-lobby:0.0" "$c" C-m
  sleep 0.12
done
t send-keys -t "fn-proxy:0.0" 'lpv group default permission set velocity.command.server true' C-m
sleep 0.2
t send-keys -t "fn-proxy:0.0" 'lpv group default permission set velocity.command.list true' C-m

echo "[FunnyNetwork] Public tunnel..."
ensure fn-tunnel "$ROOT/bin"
rm -f "$RT/logs/bore.log"
t send-keys -t "fn-tunnel:0.0" \
  "$ROOT/bin/bore-tunnel local 25565 --to bore.pub 2>&1 | tee $RT/logs/bore.log" C-m
for i in $(seq 1 20); do
  if grep -q 'listening at bore.pub' "$RT/logs/bore.log" 2>/dev/null; then
    ADDR=$(grep -oE 'bore.pub:[0-9]+' "$RT/logs/bore.log" | tail -1)
    echo "$ADDR" > "$RT/CONNECT_ADDR"
    break
  fi
  sleep 1
done

# Ping
if [[ -f "$RT/CONNECT_ADDR" ]]; then
  ADDR=$(cat "$RT/CONNECT_ADDR")
  python3 - "$ADDR" <<'PY'
import socket,struct,json,sys
addr=sys.argv[1]; host,port=addr.split(':'); port=int(port)
def varint(n):
 o=b''
 while 1:
  b=n&0x7f;n>>=7;o+=bytes([b|0x80 if n else b])
  if not n: break
 return o
s=socket.create_connection((host,port),15)
hb=host.encode();data=varint(772)+varint(len(hb))+hb+struct.pack('>H',port)+varint(1)
pkt=varint(0)+data;s.sendall(varint(len(pkt))+pkt);s.sendall(varint(1)+varint(0))
def rv():
 n=0;sh=0
 while 1:
  b=s.recv(1);n|=(b[0]&0x7f)<<sh
  if not(b[0]&0x80):return n
  sh+=7
rv();rv();sl=rv();buf=b''
while len(buf)<sl:buf+=s.recv(sl-len(buf))
j=json.loads(buf)
print('PUBLIC_OK', j['version']['name'], j['players'])
PY
  echo ""
  echo "============================================"
  echo "  JOIN NOW:  $(cat "$RT/CONNECT_ADDR")"
  echo "  Offline mode — any nickname"
  echo "  /menu  |  /server list"
  echo "============================================"
else
  echo "[FunnyNetwork] Tunnel failed — check $RT/logs/bore.log"
fi
