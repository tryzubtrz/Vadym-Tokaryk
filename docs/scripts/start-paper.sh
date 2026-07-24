#!/usr/bin/env bash
# Usage: FUNNY_SERVER_ID=surv-01 FUNNY_SYNC_GROUP=surv FUNNY_MODE=surv ./start-paper.sh /opt/funny/servers/surv-01
set -euo pipefail

SERVER_DIR="${1:-.}"
cd "$SERVER_DIR"

# shellcheck disable=SC1091
source /opt/funny/secrets/db.env

: "${FUNNY_SERVER_ID:?set FUNNY_SERVER_ID}"
: "${FUNNY_SYNC_GROUP:?set FUNNY_SYNC_GROUP}"
: "${FUNNY_MODE:?set FUNNY_MODE}"
export FUNNY_SERVER_ID FUNNY_SYNC_GROUP FUNNY_MODE
export FUNNY_SERVER_ROLE="${FUNNY_SERVER_ROLE:-game}"

MEMORY="${MEMORY:-12G}"
JAVA_BIN="${JAVA_BIN:-/usr/lib/jvm/java-21-openjdk/bin/java}"
JAR="${JAR:-purpur.jar}"

exec "$JAVA_BIN" -Xms"${MEMORY}" -Xmx"${MEMORY}" \
  -XX:+UseG1GC \
  -XX:+ParallelRefProcEnabled \
  -XX:MaxGCPauseMillis=200 \
  -XX:+UnlockExperimentalVMOptions \
  -XX:+DisableExplicitGC \
  -XX:G1NewSizePercent=30 \
  -XX:G1MaxNewSizePercent=40 \
  -XX:G1HeapRegionSize=8M \
  -XX:G1ReservePercent=20 \
  -XX:InitiatingHeapOccupancyPercent=15 \
  -XX:G1MixedGCLiveThresholdPercent=90 \
  -XX:G1RSetUpdatingPauseTimePercent=5 \
  -XX:SurvivorRatio=32 \
  -XX:+PerfDisableSharedMem \
  -XX:MaxTenuringThreshold=1 \
  -Dusing.aikars.flags=https://mcflags.emc.gs \
  -Daikars.new.flags=true \
  -jar "$JAR" --nogui
