#!/usr/bin/env bash
# Download jars+plugins into runtime/ (run once on a new machine)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RT="$ROOT/runtime"
mkdir -p "$RT"/{proxy/plugins,servers,plugins-cache,secrets,logs}
cd "$RT"

echo "Downloading Purpur 1.21.4 + Velocity 3.4.0..."
curl -fsSL -o servers/.purpur.jar "https://api.purpurmc.org/v2/purpur/1.21.4/2416/download"
curl -fsSL -o proxy/velocity.jar "https://fill-data.papermc.io/v1/objects/fb599cbda6a6d01decce5e281f71f51cae7cacffcfafca32a09601f407b0583e/velocity-3.4.0-566.jar"

if [[ ! -x "$ROOT/bin/bore-tunnel" ]]; then
  curl -fsSL -o /tmp/bore.tar.gz "https://github.com/ekzhang/bore/releases/download/v0.5.2/bore-v0.5.2-x86_64-unknown-linux-musl.tar.gz"
  tar -xzf /tmp/bore.tar.gz -C "$ROOT/bin"
  mv "$ROOT/bin/bore" "$ROOT/bin/bore-tunnel"
  chmod +x "$ROOT/bin/bore-tunnel"
fi

python3 <<'PY'
import json, urllib.request, urllib.parse
from pathlib import Path
CACHE=Path("/workspace/FunnyNetwork/runtime/plugins-cache")
# allow running from any root
import os
root=Path(os.environ.get("ROOT","")) 
PY
ROOT="$ROOT" python3 <<'PY'
import json, urllib.request, urllib.parse, os
from pathlib import Path
ROOT=Path(os.environ["ROOT"])
CACHE=ROOT/"runtime"/"plugins-cache"
CACHE.mkdir(parents=True, exist_ok=True)
UA={"User-Agent":"FunnyNetwork/1.0"}
def get(url):
    req=urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=120) as r: return r.read()
def latest(project, loaders, game=None):
    params=["loaders="+urllib.parse.quote(json.dumps(loaders))]
    if game: params.append("game_versions="+urllib.parse.quote(json.dumps(game)))
    data=json.loads(get(f"https://api.modrinth.com/v2/project/{project}/version?"+"&".join(params)))
    return data[0]["files"][0]["url"]
items=[
 ("luckperms",["bukkit","paper"],None,"LuckPerms.jar"),
 ("luckperms",["velocity"],None,"LuckPerms-Velocity.jar"),
 ("viaversion",["velocity"],None,"ViaVersion-Velocity.jar"),
 ("placeholderapi",["paper","bukkit"],None,"PlaceholderAPI.jar"),
 ("essentialsx",["paper","bukkit"],None,"EssentialsX.jar"),
 ("tab-was-taken",["paper"],None,"TAB.jar"),
 ("deluxemenus",["paper","bukkit"],None,"DeluxeMenus.jar"),
 ("fancyholograms",["paper"],["1.21.4"],"FancyHolograms.jar"),
 ("fancynpcs",["paper"],None,"FancyNpcs.jar"),
 ("playerpoints",["paper","bukkit"],None,"PlayerPoints.jar"),
]
for proj,loaders,game,out in items:
    url=latest(proj,loaders,game)
    (CACHE/out).write_bytes(get(url)); print("OK", out)
(CACHE/"Vault.jar").write_bytes(get("https://github.com/MilkBowl/Vault/releases/download/1.7.3/Vault.jar"))
print("OK Vault.jar")
print("Done. Next: generate network (see README) or reuse existing runtime/servers.")
PY

echo "Downloads complete."
