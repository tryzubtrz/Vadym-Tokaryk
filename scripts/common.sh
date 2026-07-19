#!/usr/bin/env bash
# Спільні змінні мережі MineLegacy
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CACHE="$ROOT/.cache"
UA="MineLegacy/2.0 (github.com/tryzubtrz/vadym-tokaryk)"
MC_VERSION="1.21.11"
VELOCITY_VERSION="3.5.1"

export ROOT CACHE UA MC_VERSION VELOCITY_VERSION

SERVERS=(lobby minigames survival skyblock prison factions anarchy)

declare -A SERVER_PORTS=(
  [lobby]=25566
  [minigames]=25567
  [survival]=25568
  [skyblock]=25569
  [prison]=25570
  [factions]=25571
  [anarchy]=25572
)

# Пам'ять під ~15 ГБ хоста
declare -A SERVER_MEMORY=(
  [lobby]=768M
  [minigames]=1536M
  [survival]=1280M
  [skyblock]=1280M
  [prison]=768M
  [factions]=1024M
  [anarchy]=1024M
)

VELOCITY_MEMORY="384M"

FORWARDING_SECRET_FILE="$ROOT/config/forwarding.secret"

ensure_forwarding_secret() {
  if [[ ! -f "$FORWARDING_SECRET_FILE" ]]; then
    mkdir -p "$ROOT/config"
    openssl rand -hex 16 > "$FORWARDING_SECRET_FILE"
    echo "Створено forwarding.secret"
  fi
  cp "$FORWARDING_SECRET_FILE" "$ROOT/velocity/forwarding.secret"
}

log() {
  echo -e "\033[1;33m[MineLegacy]\033[0m $*"
}

err() {
  echo -e "\033[1;31m[Помилка]\033[0m $*" >&2
}
