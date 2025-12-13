#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail
ROOT="${STATION_ROOT:-$HOME/station_root}"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$ROOT/backups/station_backup_$TS.tgz"
mkdir -p "$ROOT/backups"

tar -czf "$OUT" \
  --exclude="**/node_modules" \
  --exclude="**/.venv" \
  --exclude="**/dist" \
  --exclude="**/.vite" \
  --exclude="**/__pycache__" \
  --exclude="**/*.pyc" \
  -C "$ROOT" \
  backend frontend scripts ops docs README.md .gitignore station_env.sh app_storage station_logs 2>/dev/null || true

echo "BACKUP: $OUT"
