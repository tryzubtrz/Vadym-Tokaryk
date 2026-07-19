#!/usr/bin/env bash
if [[ -f /workspace/logs/tunnel.log ]] && grep -q "listening at" /workspace/logs/tunnel.log; then
  ADDR=$(grep -oE 'bore\.pub:[0-9]+' /workspace/logs/tunnel.log | tail -1)
  echo "Адреса MineLegacy (тунель): ${ADDR}"
else
  IP=$(curl -fsS --max-time 5 ifconfig.me 2>/dev/null || echo "невідомо")
  echo "Адреса MineLegacy: ${IP}:25565"
fi
echo "Версія: 1.21.x | TLauncher OK | /menu /donate"
echo "Режими: lobby minigames survival skyblock prison factions anarchy"
