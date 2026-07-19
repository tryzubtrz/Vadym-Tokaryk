#!/usr/bin/env bash
# Завантаження Paper, Velocity та плагінів
set -euo pipefail
source "$(dirname "$0")/common.sh"

mkdir -p "$CACHE" "$ROOT/velocity/plugins"
for s in "${SERVERS[@]}"; do
  mkdir -p "$ROOT/servers/$s/plugins"
done

ensure_forwarding_secret

download() {
  local url="$1" dest="$2"
  if [[ -f "$dest" ]]; then
    log "Вже є: $(basename "$dest")"
    return 0
  fi
  log "Завантаження: $(basename "$dest")"
  curl -fL --retry 3 -H "User-Agent: $UA" -o "$dest.tmp" "$url"
  mv "$dest.tmp" "$dest"
}

log "Отримання Paper $MC_VERSION..."
if [[ ! -f "$CACHE/paper.jar" ]]; then
  PAPER_JSON=$(curl -fsSL -H "User-Agent: $UA" \
    "https://fill.papermc.io/v3/projects/paper/versions/${MC_VERSION}/builds")
  PAPER_URL=$(echo "$PAPER_JSON" | jq -r \
    'first(.[] | select(.channel == "STABLE") | .downloads."server:default".url) // .[0].downloads."server:default".url')
  download "$PAPER_URL" "$CACHE/paper.jar"
fi

log "Отримання Velocity $VELOCITY_VERSION..."
if [[ ! -f "$CACHE/velocity.jar" ]]; then
  VEL_JSON=$(curl -fsSL -H "User-Agent: $UA" \
    "https://fill.papermc.io/v3/projects/velocity/versions/${VELOCITY_VERSION}/builds")
  VEL_URL=$(echo "$VEL_JSON" | jq -r \
    'first(.[] | select(.channel == "RECOMMENDED" or .channel == "STABLE") | .downloads."server:default".url) // .[0].downloads."server:default".url')
  download "$VEL_URL" "$CACHE/velocity.jar"
fi

cp "$CACHE/velocity.jar" "$ROOT/velocity/velocity.jar"
for s in "${SERVERS[@]}"; do
  cp "$CACHE/paper.jar" "$ROOT/servers/$s/paper.jar"
done

# --- Плагіни ---
PLUGINS_CACHE="$CACHE/plugins"
mkdir -p "$PLUGINS_CACHE"

download_modrinth() {
  local slug="$1" dest="$2"
  local url
  url=$(curl -fsSL "https://api.modrinth.com/v2/project/${slug}/version?limit=1" \
    | jq -r '.[0].files[] | select(.primary) | .url')
  download "$url" "$dest"
}

log "Плагіни..."
download_modrinth "viaversion" "$PLUGINS_CACHE/ViaVersion.jar"
download_modrinth "viabackwards" "$PLUGINS_CACHE/ViaBackwards.jar"
download "https://cdn.modrinth.com/data/Vebnzrzj/versions/MBSY8toc/LuckPerms-Bukkit-5.5.53.jar" \
  "$PLUGINS_CACHE/LuckPerms-Bukkit.jar"
download "https://cdn.modrinth.com/data/Vebnzrzj/versions/BmxJvHsa/LuckPerms-Velocity-5.5.53.jar" \
  "$PLUGINS_CACHE/LuckPerms-Velocity.jar"
download "https://cdn.modrinth.com/data/8sg1aj4I/versions/nUPEYDAm/BedWars-0.2.44.jar" \
  "$PLUGINS_CACHE/ScreamingBedWars.jar"
download "https://cdn.modrinth.com/data/uVMG0MzO/versions/uW7U72pZ/IridiumSkyblock-4.1.5-b2.jar" \
  "$PLUGINS_CACHE/IridiumSkyblock.jar"
download "https://cdn.modrinth.com/data/KqTWR5Ji/versions/fouIp34g/ImprovedFactions-2.3.0.234.jar" \
  "$PLUGINS_CACHE/ImprovedFactions.jar"
download "https://cdn.modrinth.com/data/IFN012qu/versions/aXqIRvSY/FluffyLobby-1.7.3.jar" \
  "$PLUGINS_CACHE/FluffyLobby.jar"
download "https://cdn.spiget.org/file/spiget-resources/1223.jar" \
  "$PLUGINS_CACHE/Prison.jar"

# ViaVersion на Velocity (підтримка різних клієнтів)
cp "$PLUGINS_CACHE/ViaVersion.jar" "$ROOT/velocity/plugins/"
cp "$PLUGINS_CACHE/LuckPerms-Velocity.jar" "$ROOT/velocity/plugins/"

# Спільні плагіни на кожен Paper
for s in "${SERVERS[@]}"; do
  cp "$PLUGINS_CACHE/ViaVersion.jar" "$ROOT/servers/$s/plugins/"
  cp "$PLUGINS_CACHE/ViaBackwards.jar" "$ROOT/servers/$s/plugins/"
  cp "$PLUGINS_CACHE/LuckPerms-Bukkit.jar" "$ROOT/servers/$s/plugins/"
done

cp "$PLUGINS_CACHE/FluffyLobby.jar" "$ROOT/servers/lobby/plugins/"
cp "$PLUGINS_CACHE/ScreamingBedWars.jar" "$ROOT/servers/minigames/plugins/"
cp "$PLUGINS_CACHE/IridiumSkyblock.jar" "$ROOT/servers/skyblock/plugins/"
cp "$PLUGINS_CACHE/Prison.jar" "$ROOT/servers/prison/plugins/"
cp "$PLUGINS_CACHE/ImprovedFactions.jar" "$ROOT/servers/factions/plugins/"

# Конфіги бекендів
for s in "${SERVERS[@]}"; do
  PORT="${SERVER_PORTS[$s]}"
  DIR="$ROOT/servers/$s"
  SECRET=$(cat "$FORWARDING_SECRET_FILE")

  cat > "$DIR/eula.txt" <<EOF
# Прийняття EULA Minecraft
eula=true
EOF

  cat > "$DIR/server.properties" <<EOF
# Українська мережа Тризуб — сервер $s
motd=\\u00A79Тризуб \\u00A77| \\u00A7f$s
server-port=$PORT
server-ip=127.0.0.1
online-mode=false
max-players=30
difficulty=normal
gamemode=survival
force-gamemode=false
pvp=true
spawn-protection=0
view-distance=8
simulation-distance=6
allow-flight=true
enable-command-block=true
white-list=false
enforce-whitelist=false
spawn-monsters=true
spawn-animals=true
spawn-npcs=true
level-name=world
level-type=minecraft\:normal
sync-chunk-writes=true
network-compression-threshold=256
EOF

  # Специфіка режимів
  case "$s" in
    lobby)
      sed -i 's/^gamemode=.*/gamemode=adventure/' "$DIR/server.properties"
      sed -i 's/^pvp=.*/pvp=false/' "$DIR/server.properties"
      sed -i 's/^difficulty=.*/difficulty=peaceful/' "$DIR/server.properties"
      sed -i 's/^spawn-monsters=.*/spawn-monsters=false/' "$DIR/server.properties"
      ;;
    minigames)
      sed -i 's/^pvp=.*/pvp=true/' "$DIR/server.properties"
      sed -i 's/^difficulty=.*/difficulty=normal/' "$DIR/server.properties"
      ;;
    prison)
      sed -i 's/^difficulty=.*/difficulty=hard/' "$DIR/server.properties"
      ;;
    factions)
      sed -i 's/^pvp=.*/pvp=true/' "$DIR/server.properties"
      sed -i 's/^difficulty=.*/difficulty=hard/' "$DIR/server.properties"
      ;;
  esac

  mkdir -p "$DIR/config"
  cat > "$DIR/config/paper-global.yml" <<EOF
# Paper + Velocity modern forwarding
_version: 31
proxies:
  velocity:
    enabled: true
    online-mode: true
    secret: '$SECRET'
  bungee-cord:
    online-mode: true
spigot-config:
  replace-bukkit-config: false
EOF

  # bukkit.yml / spigot мінімум
  cat > "$DIR/bukkit.yml" <<EOF
settings:
  allow-end: true
  warn-on-overload: true
  permissions-file: permissions.yml
  update-folder: update
  plugin-profiling: false
  connection-throttle: -1
  query-plugins: false
  deprecated-verbose: default
  shutdown-message: Сервер Тризуб перезавантажується...
  minimum-api: none
  use-map-color-cache: true
spawn-limits:
  monsters: 70
  animals: 10
  water-animals: 5
  water-ambient: 20
  water-underground-creature: 5
  axolotls: 5
  ambient: 15
chunk-gc:
  period-in-ticks: 600
ticks-per:
  animal-spawns: 400
  monster-spawns: 1
  water-spawns: 1
  water-ambient-spawns: 1
  water-underground-creature-spawns: 1
  axolotl-spawns: 1
  ambient-spawns: 1
  autosave: 6000
aliases: now-in-commands.yml
EOF
done

# Українські підказки в лобі
mkdir -p "$ROOT/servers/lobby/plugins/TryzubLobby"
cat > "$ROOT/servers/lobby/plugins/TryzubLobby/welcome.txt" <<'EOF'
§9§lТризуб §7| §fЛаскаво просимо!
§eКоманди переходу між режимами:
§a/server lobby §7— лобі
§a/server minigames §7— міні-ігри (BedWars)
§a/server survival §7— виживання
§a/server skyblock §7— скайблок
§a/server prison §7— в'язниця
§a/server factions §7— фракції
§bГрайте разом з друзями!
EOF

# FluffyLobby базові повідомлення (якщо плагін створить конфіг — підказка поруч)
cat > "$ROOT/servers/lobby/UKRAINIAN.txt" <<'EOF'
Мережа Тризуб — лобі
Використовуйте /server <назва> щоб перейти:
  lobby, minigames, survival, skyblock, prison, factions
EOF

log "Готово! Далі запустіть: ./scripts/start.sh"
