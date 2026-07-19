#!/usr/bin/env bash
# Повне доведення мережі Тризуб до стану «запускай і грай»
set -euo pipefail
source "$(dirname "$0")/common.sh"

log "=== Тризуб: повна підготовка мережі ==="

"$ROOT/scripts/setup.sh"
ensure_forwarding_secret

# Зібрати плагін автоналаштування
if [[ ! -f "$ROOT/servers/lobby/libraries/io/papermc/paper/paper-api/1.21.11-R0.1-SNAPSHOT/paper-api-1.21.11-R0.1-SNAPSHOT.jar" ]]; then
  log "Потрібен перший запуск Paper для бібліотек — стартуємо коротко lobby..."
  # мінімальний старт щоб стягнути libraries
  cp "$CACHE/paper.jar" "$ROOT/servers/lobby/paper.jar"
  (cd "$ROOT/servers/lobby" && java -Xms512M -Xmx512M -jar paper.jar --nogui > "$ROOT/logs/lobby-bootstrap.log" 2>&1 &)
  BPID=$!
  for i in $(seq 1 60); do
    grep -q "Done (" "$ROOT/logs/lobby-bootstrap.log" 2>/dev/null && break
    sleep 5
  done
  kill "$BPID" 2>/dev/null || true
  wait "$BPID" 2>/dev/null || true
fi

"$ROOT/tools/tryzub-setup/build.sh"
SETUP_JAR="$ROOT/tools/tryzub-setup/build/TryzubSetup.jar"

PLUGINS_CACHE="$CACHE/plugins"
mkdir -p "$PLUGINS_CACHE"

download() {
  local url="$1" dest="$2"
  if [[ -f "$dest" ]]; then return 0; fi
  log "Завантаження: $(basename "$dest")"
  curl -fL --retry 3 -H "User-Agent: $UA" -o "$dest.tmp" "$url"
  mv "$dest.tmp" "$dest"
}

log "Додаткові плагіни (економіка, захист, TAB)..."
download "https://cdn.modrinth.com/data/hXiIvTyT/versions/nY6VN1XH/EssentialsX-2.22.0.jar" "$PLUGINS_CACHE/EssentialsX.jar"
download "https://cdn.modrinth.com/data/sYpvDxGJ/versions/lc5JHiNJ/EssentialsXSpawn-2.22.0.jar" "$PLUGINS_CACHE/EssentialsXSpawn.jar"
download "https://cdn.modrinth.com/data/2qgyQbO1/versions/2k7YvKOk/EssentialsXChat-2.22.0.jar" "$PLUGINS_CACHE/EssentialsXChat.jar"
download "https://cdn.modrinth.com/data/lKEzGugV/versions/pIvQcXW8/PlaceholderAPI-2.12.3.jar" "$PLUGINS_CACHE/PlaceholderAPI.jar"
# Java 21 сумісні збірки (не 26.x / class 69)
download "https://cdn.modrinth.com/data/1u6JkXh5/versions/p8T2aZ8U/worldedit-bukkit-7.4.2.jar" "$PLUGINS_CACHE/WorldEdit.jar" || true
download "https://cdn.modrinth.com/data/DKY9btbd/versions/WaElxvDz/worldguard-bukkit-7.0.15.jar" "$PLUGINS_CACHE/WorldGuard.jar" || true
download "https://cdn.modrinth.com/data/O4o4mKaq/versions/dGfCZHqk/GriefPrevention.jar" "$PLUGINS_CACHE/GriefPrevention.jar" || true
# TAB
TAB_URL=$(curl -fsSL "https://api.modrinth.com/v2/project/tab-was-taken/version?limit=1" | jq -r '.[0].files[]|select(.primary)|.url')
download "$TAB_URL" "$PLUGINS_CACHE/TAB.jar"

# Спільний LuckPerms (YAML)
mkdir -p "$ROOT/shared/luckperms/yaml-storage"
cat > "$ROOT/shared/luckperms/config-snippet.yml" <<'EOF'
# Фрагмент: storage-method yaml + спільна тека
EOF

install_common() {
  local s="$1"
  local dir="$ROOT/servers/$s/plugins"
  mkdir -p "$dir"
  cp "$PLUGINS_CACHE/EssentialsX.jar" "$dir/"
  cp "$PLUGINS_CACHE/EssentialsXSpawn.jar" "$dir/"
  cp "$PLUGINS_CACHE/EssentialsXChat.jar" "$dir/"
  cp "$PLUGINS_CACHE/PlaceholderAPI.jar" "$dir/"
  cp "$PLUGINS_CACHE/TAB.jar" "$dir/"
  [[ -f "$PLUGINS_CACHE/WorldEdit.jar" ]] && cp "$PLUGINS_CACHE/WorldEdit.jar" "$dir/"
  [[ -f "$PLUGINS_CACHE/WorldGuard.jar" ]] && cp "$PLUGINS_CACHE/WorldGuard.jar" "$dir/"
  cp "$SETUP_JAR" "$dir/TryzubSetup.jar"
}

for s in "${SERVERS[@]}"; do
  install_common "$s"
done
# Survival claims
[[ -f "$PLUGINS_CACHE/GriefPrevention.jar" ]] && cp "$PLUGINS_CACHE/GriefPrevention.jar" "$ROOT/servers/survival/plugins/"

# TryzubSetup mode configs
for s in lobby minigames skyblock prison factions survival; do
  mkdir -p "$ROOT/servers/$s/plugins/TryzubSetup"
  cat > "$ROOT/servers/$s/plugins/TryzubSetup/config.yml" <<EOF
mode: $s
force-rebuild: true
EOF
  rm -f "$ROOT/servers/$s/plugins/TryzubSetup/bootstrapped.flag"
done

# LuckPerms → спільне YAML-сховище
log "Налаштування LuckPerms (спільні права)..."
for s in "${SERVERS[@]}"; do
  lp="$ROOT/servers/$s/plugins/LuckPerms"
  mkdir -p "$lp"
  if [[ -f "$lp/config.yml" ]]; then
    python3 - <<PY
from pathlib import Path
p = Path("$lp/config.yml")
t = p.read_text()
import re
t = re.sub(r"(?m)^server:.*$", "server: $s", t, count=1)
t = re.sub(r"(?m)^storage-method:.*$", "storage-method: yaml", t, count=1)
# yaml-storage-file path — LuckPerms uses relative yaml-storage/
p.write_text(t)
PY
  fi
  rm -rf "$lp/yaml-storage"
  ln -sfn "$ROOT/shared/luckperms/yaml-storage" "$lp/yaml-storage"
done
# Velocity LP
vlp="$ROOT/velocity/plugins/luckperms"
if [[ -d "$vlp" ]]; then
  python3 - <<PY
from pathlib import Path
import re
p = Path("$vlp/config.yml")
if p.exists():
    t = p.read_text()
    t = re.sub(r"(?m)^server:.*$", "server: proxy", t, count=1)
    t = re.sub(r"(?m)^storage-method:.*$", "storage-method: yaml", t, count=1)
    p.write_text(t)
PY
  rm -rf "$vlp/yaml-storage"
  ln -sfn "$ROOT/shared/luckperms/yaml-storage" "$vlp/yaml-storage"
fi

# Групи LuckPerms (YAML)
GROUPS="$ROOT/shared/luckperms/yaml-storage/groups"
mkdir -p "$GROUPS" "$ROOT/shared/luckperms/yaml-storage/tracks" "$ROOT/shared/luckperms/yaml-storage/users"
cat > "$GROUPS/default.yml" <<'EOF'
name: default
permissions:
- essentials.help: true
- essentials.motd: true
- essentials.spawn: true
- essentials.tpa: true
- essentials.tpaccept: true
- essentials.tpdeny: true
- essentials.home: true
- essentials.sethome: true
- essentials.delhome: true
- essentials.msg: true
- essentials.balance: true
- essentials.pay: true
- essentials.kit: true
- essentials.kits.novachok: true
- bw.command.join: true
- bw.command.leave: true
- bw.command.rejoin: true
- bw.command.stats: true
- bw.command.list: true
- iridiumskyblock.island.create: true
- iridiumskyblock.island.home: true
- iridiumskyblock.island.help: true
- griefprevention.claims: true
- griefprevention.createclaims: true
- lobby.spawn: true
prefixes:
- '0': '&7Гравець &f'
EOF

cat > "$GROUPS/vip.yml" <<'EOF'
name: vip
parents:
- default
permissions:
- essentials.fly: true
- essentials.kits.vip: true
- bw.vip.startitem: true
prefixes:
- '10': '&aVIP &f'
EOF

cat > "$GROUPS/helper.yml" <<'EOF'
name: helper
parents:
- vip
permissions:
- essentials.kick: true
- essentials.mute: true
- essentials.tp: true
- essentials.vanish: true
prefixes:
- '50': '&9Хелпер &f'
EOF

cat > "$GROUPS/admin.yml" <<'EOF'
name: admin
parents:
- helper
permissions:
- '*': true
- luckperms.*: true
- essentials.*: true
- bw.admin: true
- worldedit.*: true
- worldguard.*: true
- tryzub.setup: true
- minecraft.command.op: true
prefixes:
- '100': '&cАдмін &f'
EOF

cat > "$GROUPS/owner.yml" <<'EOF'
name: owner
parents:
- admin
permissions:
- '*': true
prefixes:
- '1000': '&4&lВласник &f'
EOF

cat > "$ROOT/shared/luckperms/yaml-storage/tracks/staff.yml" <<'EOF'
name: staff
groups:
- default
- vip
- helper
- admin
- owner
EOF

# Власник за ніком Vadym (офлайн UUID згенеруємо пізніше скриптом)
cat > "$ROOT/config/owners.txt" <<'EOF'
Vadym
vadym
EOF

# Skyblock paster fix
if [[ -f "$ROOT/servers/skyblock/plugins/IridiumSkyblock/configuration.yml" ]]; then
  sed -i 's/paster: "worldedit"/paster: "internalAsync"/; s/paster: worldedit/paster: internalAsync/' \
    "$ROOT/servers/skyblock/plugins/IridiumSkyblock/configuration.yml"
  # створювати острів при заході — зручніше для новачків
  sed -i 's/islandCreateOnJoin: false/islandCreateOnJoin: true/' \
    "$ROOT/servers/skyblock/plugins/IridiumSkyblock/configuration.yml" || true
fi

# BedWars UA + mainlobby
BWCFG="$ROOT/servers/minigames/plugins/BedWars/config.yml"
if [[ -f "$BWCFG" ]]; then
  python3 - <<PY
from pathlib import Path
p = Path("$BWCFG")
t = p.read_text()
t = t.replace("locale: en", "locale: uk", 1)
# mainlobby block
import re
if "mainlobby:" in t:
    t = re.sub(r"(?ms)^mainlobby:.*?(?=^[a-zA-Z]|\Z)",
               "mainlobby:\n  enabled: true\n  location: 0.5;121.0;0.5;0.0;0.0\n  world: world\n\n",
               t, count=1)
else:
    t += "\nmainlobby:\n  enabled: true\n  location: 0.5;121.0;0.5;0.0;0.0\n  world: world\n"
# join randomly helps solo testing with friends
t = t.replace("join-randomly-on-lobby-join: false", "join-randomly-on-lobby-join: true", 1)
t = t.replace("join-randomly-after-lobby-timeout: false", "join-randomly-after-lobby-timeout: true", 1)
p.write_text(t)
print("BedWars config updated")
PY
fi

# FluffyLobby polish
LOBBY_FL="$ROOT/servers/lobby/plugins/FluffyLobby/config.yml"
if [[ -f "$LOBBY_FL" ]]; then
  python3 - <<'PY'
from pathlib import Path
p = Path("/workspace/servers/lobby/plugins/FluffyLobby/config.yml")
t = p.read_text()
t = t.replace("effect: 'wither'", "effect: 'none'")
t = t.replace("slot: 9", "slot: 4")
t = t.replace("slot: 10", "slot: 8")
t = t.replace("slot: 1\n", "slot: 0\n", 1)
# spawn
import re
t = re.sub(r"(?ms)^spawn:.*?^################",
           "spawn:\n  world: 'world'\n  x: 0.5\n  y: 101\n  z: 0.5\n  yaw: 0.0\n  pitch: 0.0\n\n################",
           t, count=1)
p.write_text(t)
# sync template
Path("/workspace/config/templates/FluffyLobby/config.yml").write_text(t)
print("FluffyLobby updated")
PY
fi

# RCON пароль
RCON_PASS=$(openssl rand -hex 8)
echo "$RCON_PASS" > "$ROOT/config/rcon.password"

# Фіксовані rcon порти простіше
declare -A RCON_PORTS=([lobby]=25580 [minigames]=25581 [survival]=25582 [skyblock]=25583 [prison]=25584 [factions]=25585 [anarchy]=25586)
for s in "${SERVERS[@]}"; do
  props="$ROOT/servers/$s/server.properties"
  python3 - <<PY
from pathlib import Path
p = Path("$props")
text = p.read_text() if p.exists() else ""
vals = {
  "enable-rcon": "true",
  "rcon.port": "${RCON_PORTS[$s]}",
  "rcon.password": "$RCON_PASS",
  "broadcast-rcon-to-ops": "false",
}
lines = text.splitlines()
seen = set()
out = []
for line in lines:
    if line.startswith("#") or "=" not in line:
        out.append(line)
        continue
    k, _, v = line.partition("=")
    if k in vals:
        out.append(f"{k}={vals[k]}")
        seen.add(k)
    else:
        out.append(line)
for k, v in vals.items():
    if k not in seen:
        out.append(f"{k}={v}")
p.write_text("\n".join(out) + "\n")
print("RCON configured for $s")
PY
done

# Essentials worth + kits (після першої генерації — preseed)
for s in "${SERVERS[@]}"; do
  mkdir -p "$ROOT/servers/$s/plugins/Essentials"
  cat > "$ROOT/servers/$s/plugins/Essentials/worth.yml" <<'EOF'
worth:
  cobblestone: 0.5
  coal: 2.0
  iron_ingot: 5.0
  gold_ingot: 8.0
  diamond: 25.0
  oak_log: 1.0
EOF
  cat > "$ROOT/servers/$s/plugins/Essentials/kits.yml" <<'EOF'
kits:
  novachok:
    delay: 3600
    items:
    - bread 16
    - wooden_sword 1
    - wooden_pickaxe 1
  vip:
    delay: 1800
    items:
    - cooked_beef 32
    - iron_sword 1
    - iron_pickaxe 1
EOF
done

# TAB українською (базовий)
for s in "${SERVERS[@]}"; do
  mkdir -p "$ROOT/servers/$s/plugins/TAB"
done

# Очистити маркери і частково світи лобі/мініігор для чистої забудови? 
# Не видаляємо весь світ — плагін будує поверх. force-rebuild=true достатньо.

# Velocity MOTD уже український
log "Запуск мережі..."
"$ROOT/scripts/start.sh"

log "Чекаємо готовності серверів..."
for i in $(seq 1 48); do
  ready=0
  for s in "${SERVERS[@]}"; do
    grep -q "Done (" "$ROOT/logs/${s}.log" 2>/dev/null && ready=$((ready+1))
  done
  echo "  готові: $ready/6"
  [[ $ready -eq 6 ]] && break
  sleep 8
done

# Post: власник + prison autoconfigure через RCON
sleep 15
python3 "$ROOT/scripts/post-ready.py" || log "post-ready частково не виконано (можна повторити)"

# Тунель
if ! pgrep -f "bore local 25565" >/dev/null 2>&1; then
  log "Запуск тунелю bore.pub..."
  SESSION_NAME="mc-tunnel"
  tmux -f /exec-daemon/tmux.portal.conf has-session -t "=$SESSION_NAME" 2>/dev/null || \
    tmux -f /exec-daemon/tmux.portal.conf new-session -d -s "$SESSION_NAME" -c "$ROOT" -- "${SHELL:-bash}" -l
  tmux -f /exec-daemon/tmux.portal.conf send-keys -t "$SESSION_NAME:0.0" \
    "cd $ROOT/.cache && ./bore local 25565 --to bore.pub 2>&1 | tee $ROOT/logs/tunnel.log" C-m
  sleep 3
fi

"$ROOT/scripts/status.sh"
"$ROOT/scripts/ip.sh"
cat <<EOF

╔══════════════════════════════════════════════════════════╗
║     Тризуб ГОТОВИЙ ДО ГРИ                                ║
╠══════════════════════════════════════════════════════════╣
║  1) Підключись з TLauncher (офлайн)                      ║
║  2) Зайди в головне лобі                                 ║
║  3) Папір «Вибір сервера» або /server <режим>            ║
║  4) Міні-ігри: /bw join TryzubDuo                        ║
║  5) Skyblock: /is create  (або авто при вході)           ║
║  6) Адмін (нік з config/owners.txt): повні права         ║
║                                                          ║
║  Друг: та сама адреса тунелю                             ║
╚══════════════════════════════════════════════════════════╝
EOF
