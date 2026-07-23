#!/usr/bin/env bash
# Rebuild runtime/servers + proxy config from plugins-cache + .purpur.jar
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export ROOT
python3 <<'PY'
from pathlib import Path
import shutil, secrets, os
ROOT=Path(os.environ['ROOT']); RT=ROOT/'runtime'; CACHE=RT/'plugins-cache'
PURPUR=RT/'servers'/'.purpur.jar'
assert PURPUR.exists(), 'missing purpur — run bin/setup-download.sh'
assert CACHE.exists(), 'missing plugins-cache — run bin/setup-download.sh'
SECRET_FILE=RT/'secrets'/'forwarding.secret'
if SECRET_FILE.exists():
    SECRET=SECRET_FILE.read_text().strip()
else:
    SECRET=secrets.token_hex(16)
    SECRET_FILE.parent.mkdir(parents=True, exist_ok=True)
    SECRET_FILE.write_text(SECRET+'\n')
(RT/'proxy'/'forwarding.secret').write_text(SECRET+'\n')

MODES=[
    ("lobby",25566,"1400M","adventure","peaceful",False,"void","Main Lobby"),
    ("survival",25570,"1400M","survival","normal",True,"normal","Survival"),
    ("skyblock",25571,"1200M","survival","normal",True,"void","SkyBlock"),
    ("anarchy",25572,"1200M","survival","hard",True,"normal","Anarchy"),
    ("bedwars",25573,"1100M","adventure","peaceful",False,"void","BedWars"),
    ("creative",25574,"1000M","creative","peaceful",False,"flat","Creative"),
]
CORE=["LuckPerms.jar","PlaceholderAPI.jar","Vault.jar","EssentialsX.jar","TAB.jar",
      "DeluxeMenus.jar","FancyHolograms.jar","FancyNpcs.jar","PlayerPoints.jar"]
menu=(ROOT/'shared'/'menus'/'mode_selector.yml').read_text()
servers="\n".join(f'{m[0]} = "127.0.0.1:{m[1]}"' for m in MODES)
(RT/'proxy').mkdir(parents=True, exist_ok=True)
(RT/'proxy'/'velocity.toml').write_text(f'''config-version = "2.7"
bind = "0.0.0.0:25565"
motd = "<gradient:#1F6F8B:#F2C14E><bold>FunnyNetwork</bold></gradient> <gray>|</gray> <white>Survival · SkyBlock · BedWars · Anarchy</white>"
show-max-players = 5000
online-mode = false
force-key-authentication = false
player-info-forwarding-mode = "modern"
forwarding-secret-file = "forwarding.secret"
prevent-client-proxy-connections = false
announce-forge = false
kick-existing-players = false
ping-passthrough = "DISABLED"
[servers]
{servers}
try = ["lobby"]
[forced-hosts]
[advanced]
compression-threshold = 256
login-ratelimit = 300
bungee-plugin-message-channel = true
failover-on-unexpected-server-disconnect = true
announce-proxy-commands = true
[query]
enabled = true
port = 25565
map = "FunnyNetwork"
show-plugins = false
''')
pp=RT/'proxy'/'plugins'; pp.mkdir(exist_ok=True)
shutil.copy2(CACHE/'LuckPerms-Velocity.jar', pp/'LuckPerms-Velocity.jar')
shutil.copy2(CACHE/'ViaVersion-Velocity.jar', pp/'ViaVersion.jar')
lines=[]
for mid,port,mem,gm,diff,pvp,world,motd in MODES:
    sdir=RT/'servers'/mid
    # keep world if exists
    keep_world = sdir/'world' if (sdir/'world').exists() else None
    tmp=None
    if keep_world:
        tmp=RT/'servers'/f'.keep-{mid}'
        if tmp.exists(): shutil.rmtree(tmp)
        shutil.move(str(keep_world), str(tmp))
    if sdir.exists(): shutil.rmtree(sdir)
    sdir.mkdir(parents=True)
    shutil.copy2(PURPUR, sdir/'purpur.jar')
    (sdir/'eula.txt').write_text('eula=true\n')
    if world=='void':
        lt='minecraft\\:flat'; gen='generator-settings={"layers":[{"block":"minecraft:stone","height":1}],"biome":"minecraft:the_void"}\n'
    elif world=='flat':
        lt='minecraft\\:flat'; gen='generator-settings={"layers":[{"block":"minecraft:grass_block","height":1},{"block":"minecraft:dirt","height":3},{"block":"minecraft:stone","height":1}],"biome":"minecraft:plains"}\n'
    else:
        lt='minecraft\\:normal'; gen=''
    (sdir/'server.properties').write_text(f'''server-port={port}
online-mode=false
max-players=150
motd=FunnyNetwork {motd}
gamemode={gm}
force-gamemode={"false" if mid in ("survival","anarchy","skyblock") else "true"}
difficulty={diff}
pvp={"true" if pvp else "false"}
spawn-protection={"0" if mid=="anarchy" else "24"}
view-distance=5
simulation-distance=4
allow-nether={"true" if mid in ("survival","anarchy") else "false"}
allow-end=false
enforce-secure-profile=false
network-compression-threshold=256
level-name=world
level-type={lt}
{gen}white-list=false
spawn-monsters={"true" if mid in ("survival","anarchy","skyblock") else "false"}
spawn-animals={"true" if mid in ("survival","skyblock") else "false"}
sync-chunk-writes=false
''')
    (sdir/'config').mkdir(exist_ok=True)
    (sdir/'config'/'paper-global.yml').write_text(f'''proxies:
  velocity:
    enabled: true
    online-mode: false
    secret: '{SECRET}'
''')
    pdir=sdir/'plugins'; pdir.mkdir(exist_ok=True)
    for j in CORE:
        shutil.copy2(CACHE/j, pdir/j)
    dm=pdir/'DeluxeMenus'; (dm/'gui_menus').mkdir(parents=True, exist_ok=True)
    (dm/'gui_menus'/'mode_selector.yml').write_text(menu)
    (dm/'config.yml').write_text('check_updates: false\ngui_menus:\n  mode_selector:\n    file: mode_selector.yml\n')
    ess=pdir/'Essentials'; ess.mkdir(exist_ok=True)
    (ess/'motd.txt').write_text('&b&lFunnyNetwork\n&7Привет, &f{PLAYER}&7!\n&e/menu &7· &e/server list\n&e/points &7— FunnyCoins\n')
    (ess/'kits.yml').write_text('kits:\n  starter:\n    delay: 0\n    items:\n    - compass 1 name:&b&lМеню\n    - cooked_beef 16\n')
    if tmp and tmp.exists():
        shutil.move(str(tmp), str(sdir/'world'))
        (sdir/'.prepared').write_text('kept-world\n')
    lines.append(f'{mid} {port} {mem}')
    print('assembled', mid)
(RT/'modes.list').write_text('\n'.join(lines)+'\n')
print('OK secret', SECRET[:8]+'...')
PY
echo "Assemble done."
