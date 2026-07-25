#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p logs
export MEXC_SPEED_MODE="${MEXC_SPEED_MODE:-true}"
export MEXC_LIVE_CONFIRMED="${MEXC_LIVE_CONFIRMED:-true}"
export MEXC_FX_LOOP_SEC="${MEXC_FX_LOOP_SEC:-60}"
export MEXC_MICRO_RESERVE_USDC="${MEXC_MICRO_RESERVE_USDC:-5.5}"
while true; do
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) watchdog start fx swing" | tee -a logs/mexc_fx_swing_watchdog.log
  .venv/bin/python scripts/run_mexc_fx_swing.py >> logs/mexc_fx_swing.log 2>&1 || true
  if python3 - <<'PY'
import json
from pathlib import Path
p=Path('data/mexc_fx_swing.json')
if not p.exists():
    raise SystemExit(1)
s=json.loads(p.read_text())
raise SystemExit(0 if s.get('stopped') else 1)
PY
  then
    echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) fx sleeve stopped — exit" | tee -a logs/mexc_fx_swing_watchdog.log
    break
  fi
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) fx crash/restart in 5s" | tee -a logs/mexc_fx_swing_watchdog.log
  sleep 5
done
