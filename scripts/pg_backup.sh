#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

# Local backup runner (Termux)
# Requires: pkg install postgresql
ROOT="${STATION_ROOT:-$HOME/station_root}"
# shellcheck disable=SC1090
[ -f "$HOME/render_secrets.env" ] && source "$HOME/render_secrets.env" || true

: "${DATABASE_URL:?DATABASE_URL missing in env. (On Render it exists; locally export it or source secrets)}"

OUTDIR="$ROOT/backups"
mkdir -p "$OUTDIR"

TS="$(date +%Y%m%d_%H%M%S)"
OUT="$OUTDIR/pg_${TS}.dump"

echo "Creating backup: $OUT"
pg_dump "$DATABASE_URL" -Fc -f "$OUT"
ls -lh "$OUT"
echo "DONE"
