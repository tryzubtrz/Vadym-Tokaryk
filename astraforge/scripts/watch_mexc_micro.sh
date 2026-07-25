#!/usr/bin/env bash
# Keep micro AI sleeve alive; restart on crash. Hard bankroll stop is inside the bot.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p logs
export MEXC_LIVE_CONFIRMED="${MEXC_LIVE_CONFIRMED:-true}"
export MEXC_MICRO_LOOP_SEC="${MEXC_MICRO_LOOP_SEC:-45}"
while true; do
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) watchdog start micro AI" | tee -a logs/mexc_micro_ai_watchdog.log
  .venv/bin/python scripts/run_mexc_micro_ai.py >> logs/mexc_micro_ai.log 2>&1 || true
  # if state says stopped, do not restart loop forever
  if python3 - <<'PY'
import json
from pathlib import Path
p=Path('data/mexc_micro_ai.json')
if not p.exists():
    raise SystemExit(1)
s=json.loads(p.read_text())
raise SystemExit(0 if s.get('stopped') else 1)
PY
  then
    echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) sleeve stopped — watchdog exit" | tee -a logs/mexc_micro_ai_watchdog.log
    break
  fi
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) crash/restart in 5s" | tee -a logs/mexc_micro_ai_watchdog.log
  sleep 5
done
