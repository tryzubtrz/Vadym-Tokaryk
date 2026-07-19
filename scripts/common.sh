#!/usr/bin/env bash
# Спільні змінні для мережі Тризуб
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CACHE="$ROOT/.cache"
UA="TryzubMinecraft/1.0 (github.com/tryzubtrz/vadym-tokaryk)"
MC_VERSION="1.21.11"
VELOCITY_VERSION="3.5.1"

export ROOT CACHE UA MC_VERSION VELOCITY_VERSION

SERVERS=(lobby minigames survival skyblock prison factions)

# порт бекендів (лише localhost — гравці заходять через Velocity :25565)
declare -A SERVER_PORTS=(
  [lobby]=25566
  [minigames]=25567
  [survival]=25568
  [skyblock]=25569
  [prison]=25570
  [factions]=25571
)

# пам'ять JVM
declare -A SERVER_MEMORY=(
  [lobby]=1024M
  [minigames]=2048M
  [survival]=1536M
  [skyblock]=1536M
  [prison]=1024M
  [factions]=1536M
)

VELOCITY_MEMORY="512M"

FORWARDING_SECRET_FILE="$ROOT/config/forwarding.secret"

ensure_forwarding_secret() {
  if [[ ! -f "$FORWARDING_SECRET_FILE" ]]; then
    mkdir -p "$ROOT/config"
    # випадковий секрет для modern forwarding
    openssl rand -hex 16 > "$FORWARDING_SECRET_FILE"
    echo "Створено forwarding.secret"
  fi
  # Velocity читає файл у своїй теці
  cp "$FORWARDING_SECRET_FILE" "$ROOT/velocity/forwarding.secret"
}

log() {
  echo -e "\033[1;34m[Тризуб]\033[0m $*"
}

err() {
  echo -e "\033[1;31m[Помилка]\033[0m $*" >&2
}
