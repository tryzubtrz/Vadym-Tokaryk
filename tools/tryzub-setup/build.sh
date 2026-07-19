#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SRC="$(cd "$(dirname "$0")" && pwd)"
OUT="$SRC/build"
API="$ROOT/servers/lobby/libraries/io/papermc/paper/paper-api/1.21.11-R0.1-SNAPSHOT/paper-api-1.21.11-R0.1-SNAPSHOT.jar"
ADVENTURE=$(find "$ROOT/servers/lobby/libraries/net/kyori" -name 'adventure-api-*.jar' | head -1)
KEY=$(find "$ROOT/servers/lobby/libraries/net/kyori" -name 'adventure-key-*.jar' | head -1)
LOGGER=$(find "$ROOT/servers/lobby/libraries/net/kyori" -name 'adventure-text-logger-slf4j-*.jar' | head -1)
# slf4j may be needed
SLF4J=$(find "$ROOT/servers/lobby/libraries" -name 'slf4j-api-*.jar' | head -1)
GUAVA=$(find "$ROOT/servers/lobby/libraries" -path '*guava*.jar' | head -1)
GSON=$(find "$ROOT/servers/lobby/libraries" -name 'gson-*.jar' | head -1)
COMMONS=$(find "$ROOT/servers/lobby/libraries" -name 'commons-lang3-*.jar' | head -1)
BUNGEE=$(find "$ROOT/servers/lobby/libraries" -name 'bungeecord-chat-*.jar' | head -1)
LEGACY=$(find "$ROOT/servers/lobby/libraries" -name 'adventure-text-serializer-legacy-*.jar' | head -1)

CP="$API:$ADVENTURE:$KEY"
[[ -n "${SLF4J:-}" ]] && CP="$CP:$SLF4J"
[[ -n "${GUAVA:-}" ]] && CP="$CP:$GUAVA"
[[ -n "${GSON:-}" ]] && CP="$CP:$GSON"
[[ -n "${COMMONS:-}" ]] && CP="$CP:$COMMONS"
[[ -n "${LOGGER:-}" ]] && CP="$CP:$LOGGER"
[[ -n "${BUNGEE:-}" ]] && CP="$CP:$BUNGEE"
[[ -n "${LEGACY:-}" ]] && CP="$CP:$LEGACY"

rm -rf "$OUT"
mkdir -p "$OUT/classes"
echo "Компіляція TryzubSetup..."
javac --release 21 -cp "$CP" -d "$OUT/classes" \
  "$SRC/src/main/java/ua/tryzub/setup/TryzubSetupPlugin.java"
cp "$SRC/src/main/resources/plugin.yml" "$OUT/classes/"
cp "$SRC/src/main/resources/config.yml" "$OUT/classes/"
jar cfe "$OUT/TryzubSetup.jar" ua.tryzub.setup.TryzubSetupPlugin -C "$OUT/classes" .
echo "Готово: $OUT/TryzubSetup.jar"
ls -lh "$OUT/TryzubSetup.jar"
