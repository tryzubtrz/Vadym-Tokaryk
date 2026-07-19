#!/usr/bin/env bash
# Запуск усієї мережі MineLegacy
set -euo pipefail
source "$(dirname "$0")/common.sh"

ensure_forwarding_secret

if [[ ! -f "$ROOT/velocity/velocity.jar" ]] || [[ ! -f "$ROOT/servers/lobby/paper.jar" ]]; then
  log "Спочатку виконуємо setup..."
  "$ROOT/scripts/setup.sh"
fi

mkdir -p "$ROOT/logs" "$ROOT/run"

is_running() {
  local name="$1"
  local pidfile="$ROOT/run/${name}.pid"
  [[ -f "$pidfile" ]] && kill -0 "$(cat "$pidfile")" 2>/dev/null
}

start_paper() {
  local name="$1"
  local dir="$ROOT/servers/$name"
  local mem="${SERVER_MEMORY[$name]}"
  local pidfile="$ROOT/run/${name}.pid"
  local logfile="$ROOT/logs/${name}.log"

  if is_running "$name"; then
    log "$name уже запущено (pid $(cat "$pidfile"))"
    return
  fi

  log "Старт Paper: $name (${mem}, порт ${SERVER_PORTS[$name]})"
  cd "$dir"
  # Aikar flags (спрощені)
  nohup java -Xms"${mem}" -Xmx"${mem}" \
    -XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200 \
    -XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC \
    -XX:+AlwaysPreTouch -XX:G1NewSizePercent=30 -XX:G1MaxNewSizePercent=40 \
    -XX:G1HeapRegionSize=8M -XX:G1ReservePercent=20 -XX:G1HeapWastePercent=5 \
    -XX:G1MixedGCCountTarget=4 -XX:InitiatingHeapOccupancyPercent=15 \
    -XX:G1MixedGCLiveThresholdPercent=90 -XX:G1RSetUpdatingPauseTimePercent=5 \
    -XX:SurvivorRatio=32 -XX:+PerfDisableSharedMem -XX:MaxTenuringThreshold=1 \
    -Dusing.aikars.flags=https://mcflags.emc.gs -Daikars.new.flags=true \
    -jar paper.jar --nogui \
    > "$logfile" 2>&1 &
  echo $! > "$pidfile"
}

start_velocity() {
  local pidfile="$ROOT/run/velocity.pid"
  local logfile="$ROOT/logs/velocity.log"
  if is_running velocity; then
    log "Velocity уже запущено (pid $(cat "$pidfile"))"
    return
  fi
  # оновити secret
  cp "$FORWARDING_SECRET_FILE" "$ROOT/velocity/forwarding.secret"
  log "Старт Velocity (${VELOCITY_MEMORY}, порт 25565)"
  cd "$ROOT/velocity"
  nohup java -Xms"${VELOCITY_MEMORY}" -Xmx"${VELOCITY_MEMORY}" \
    -jar velocity.jar \
    > "$logfile" 2>&1 &
  echo $! > "$pidfile"
}

# Спочатку бекенди, потім проксі
for s in "${SERVERS[@]}"; do
  start_paper "$s"
done

log "Чекаємо готовності бекендів (перший запуск може зайняти кілька хвилин)..."
sleep 15

start_velocity

PUBLIC_IP=$(curl -fsS --max-time 5 ifconfig.me 2>/dev/null || echo "ВАША_IP")
cat <<EOF

╔══════════════════════════════════════════════════╗
║           MineLegacy запущено!                ║
╠══════════════════════════════════════════════════╣
║  Адреса для гри:  ${PUBLIC_IP}:25565
║  Версія:          Minecraft ${MC_VERSION} (+ ViaVersion)
║
║  Режими (/server <назва>):
║    lobby      — лобі
║    minigames  — міні-ігри (BedWars)
║    survival   — виживання
║    skyblock   — скайблок
║    prison     — в'язниця
║    factions   — фракції
║
║  Логи: ./logs/
║  Зупинка: ./scripts/stop.sh
║  Статус:  ./scripts/status.sh
╚══════════════════════════════════════════════════╝
EOF
