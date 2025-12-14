#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="${STATION_ROOT:-$HOME/station_root}"
cd "$ROOT"

echo "=============================================="
echo "STATION_041C_GITHUB_SIZE_AUDIT_GOLD"
echo "root: $ROOT"
date
echo "=============================================="
echo

if [ ! -d .git ]; then
  echo "ERROR: Not a git repo (.git missing) in: $ROOT"
  exit 1
fi

echo ">>> 0) Repo identity"
echo "branch: $(git branch --show-current || true)"
echo "HEAD:   $(git rev-parse --short HEAD)"
echo

echo ">>> A) Git object database size (closest to GitHub stored size)"
git count-objects -vH || true
echo

echo ">>> B) Total tracked bytes at HEAD (sum of blobs) [may take time]"
calc_total_head() {
  git ls-files -z \
  | tr '\0' '\n' \
  | git cat-file --batch-check='%(objectsize)' --stdin \
  | awk '{s+=$1} END{printf "%.0f\n", s+0}'
}

TOTAL=""
if command -v timeout >/dev/null 2>&1; then
  # 180s guard to survive large repos on Termux
  TOTAL="$(timeout 180s bash -lc 'calc_total_head' 2>/dev/null || true)"
else
  TOTAL="$(calc_total_head 2>/dev/null || true)"
fi

if [ -n "${TOTAL:-}" ]; then
  echo "tracked_total_bytes_head: $TOTAL"
  python - <<'PY' "$TOTAL"
import sys
b=int(sys.argv[1])
units=["B","KB","MB","GB","TB"]
u=0
x=float(b)
while x>=1024 and u<len(units)-1:
    x/=1024.0
    u+=1
print(f"tracked_total_human_head: {x:.2f} {units[u]}")
PY
else
  echo "tracked_total_bytes_head: (FAILED / TIMEOUT)"
fi
echo

echo ">>> C) Sanity: tracked node_modules?"
if git ls-files | grep -qE '^frontend/node_modules/'; then
  echo "WARN: tracked node_modules detected!"
  git ls-files | grep -E '^frontend/node_modules/' | head -n 30
else
  echo "OK: no tracked node_modules"
fi
echo

echo "DONE: STATION_041C_GITHUB_SIZE_AUDIT_GOLD"
echo "=============================================="
