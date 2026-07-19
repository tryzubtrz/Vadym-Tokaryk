#!/usr/bin/env bash
# Увімкнути Velocity forwarding у вже згенерованих paper-global.yml
set -euo pipefail
source "$(dirname "$0")/common.sh"

ensure_forwarding_secret
SECRET=$(cat "$FORWARDING_SECRET_FILE")

for s in "${SERVERS[@]}"; do
  conf="$ROOT/servers/$s/config/paper-global.yml"
  mkdir -p "$ROOT/servers/$s/config"
  if [[ ! -f "$conf" ]]; then
    cat > "$conf" <<EOF
_version: 31
proxies:
  velocity:
    enabled: true
    online-mode: false
    secret: '$SECRET'
EOF
    log "Створено paper-global.yml для $s"
    continue
  fi

  # увімкнути velocity + секрет через python (надійніше за sed для YAML)
  python3 - "$conf" "$SECRET" <<'PY'
import sys, re
path, secret = sys.argv[1], sys.argv[2]
text = open(path, encoding="utf-8").read()
if "proxies:" not in text:
    text += f"\nproxies:\n  velocity:\n    enabled: true\n    online-mode: false\n    secret: '{secret}'\n"
else:
    # enabled
    text = re.sub(r"(velocity:\s*\n(?:[^\n]*\n)*?\s*enabled:\s*)(false|true)",
                   r"\1true", text, count=1)
    if re.search(r"velocity:\s*\n(?:.*\n)*?\s*secret:\s*", text):
        text = re.sub(r"(velocity:\s*\n(?:[^\n]*\n)*?\s*secret:\s*)(['\"]?).*?(['\"]?\s*)$",
                      rf"\1'{secret}'", text, count=1, flags=re.M)
    else:
        text = re.sub(r"(velocity:\s*\n)",
                      rf"\1    secret: '{secret}'\n", text, count=1)
    if "online-mode:" not in text.split("velocity:")[1].split("\n\n")[0] if "velocity:" in text else True:
        text = re.sub(r"(velocity:\s*\n)",
                      r"\1    online-mode: false\n", text, count=1)
open(path, "w", encoding="utf-8").write(text)
print(f"Оновлено {path}")
PY
done

log "Forwarding оновлено на всіх бекендах."
