#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")/../../proxy" && pwd)"
cd "$DIR"
# shellcheck disable=SC1091
source /opt/funny/secrets/db.env

JAVA_BIN="${JAVA_BIN:-/usr/lib/jvm/java-21-openjdk/bin/java}"
exec "$JAVA_BIN" -Xms4G -Xmx4G \
  -XX:+UseG1GC \
  -XX:MaxGCPauseMillis=200 \
  -jar velocity.jar
