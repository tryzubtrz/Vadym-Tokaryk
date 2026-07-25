#!/usr/bin/env bash
set -euo pipefail

mkdir -p /app/data

echo "[AstraForge] Starting autonomous trading agent..."
exec python -m astraforge.main
