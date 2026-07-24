#!/usr/bin/env bash
set -euo pipefail
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${BACKUP_ROOT:-/opt/funny/backups}/$STAMP"
mkdir -p "$OUT"/{db,worlds}

# shellcheck disable=SC1091
source /opt/funny/secrets/db.env

mysqldump --single-transaction --routines --triggers \
  -h"${MYSQL_HOST}" -u"${MYSQL_BACKUP_USER}" -p"${MYSQL_BACKUP_PASS}" \
  --databases funny_global funny_surv funny_sb funny_luckperms \
  | zstd -T0 -19 > "$OUT/db/funny.sql.zst"

for w in surv-01 sb-01; do
  WORLD_DIR="/opt/funny/servers/$w"
  if [[ -d "$WORLD_DIR" ]]; then
    tar -C "$WORLD_DIR" -cf - world world_nether world_the_end 2>/dev/null \
      | zstd -T0 -10 > "$OUT/worlds/${w}.tar.zst" || true
  fi
done

find "${BACKUP_ROOT:-/opt/funny/backups}" -mindepth 1 -maxdepth 1 -mtime +7 -exec rm -rf {} \;
echo "Backup done: $OUT"
