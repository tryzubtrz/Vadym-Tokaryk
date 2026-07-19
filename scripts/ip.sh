#!/usr/bin/env bash
IP=$(curl -fsS --max-time 5 ifconfig.me 2>/dev/null || echo "невідомо")
echo "Адреса для Minecraft: ${IP}:25565"
echo "Версія клієнта: 1.21.x (ViaVersion підтримує близькі версії)"
echo "Режим: офлайн (можна заходити з TLauncher)"
