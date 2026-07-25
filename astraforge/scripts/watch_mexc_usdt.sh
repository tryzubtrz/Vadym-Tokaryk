#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p logs
export MEXC_SPEED_MODE="${MEXC_SPEED_MODE:-true}"
export MEXC_LIVE_CONFIRMED="${MEXC_LIVE_CONFIRMED:-true}"
export MEXC_USDT_LOOP_SEC="${MEXC_USDT_LOOP_SEC:-20}"
while true; do
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) watchdog start usdt candle" | tee -a logs/mexc_usdt_candle_watchdog.log
  .venv/bin/python scripts/run_mexc_usdt_candle.py >> logs/mexc_usdt_candle.log 2>&1 || true
  if python3 - <<'PY'
import json
from pathlib import Path
p=Path('data/mexc_usdt_candle.json')
raise SystemExit(0 if p.exists() and json.loads(p.read_text()).get('stopped') else 1)
PY
  then
    echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) usdt sleeve stopped" | tee -a logs/mexc_usdt_candle_watchdog.log
    break
  fi
  sleep 5
done
