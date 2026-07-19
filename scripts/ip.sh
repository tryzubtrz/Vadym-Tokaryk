#!/usr/bin/env bash
if [[ -f /workspace/logs/tunnel.log ]] && grep -q "listening at" /workspace/logs/tunnel.log; then
  ADDR=$(grep -oE 'bore\.pub:[0-9]+' /workspace/logs/tunnel.log | tail -1)
  echo "Адреса для Minecraft (тунель): ${ADDR}"
else
  IP=$(curl -fsS --max-time 5 ifconfig.me 2>/dev/null || echo "невідомо")
  echo "Адреса для Minecraft: ${IP}:25565"
fi
echo "Версія клієнта: 1.21.x (ViaVersion підтримує близькі версії)"
echo "Режим: офлайн (можна заходити з TLauncher)"
echo "Нік: будь-який (наприклад Vadym)"
