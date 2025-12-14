#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="${STATION_ROOT:-$HOME/station_root}"
cd "$ROOT"

echo "=============================================="
echo "STATION_041B_GITHUB_SIZE_AUDIT_FAST"
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

echo ">>> 1) Total tracked bytes at HEAD (fast batch mode)"
# Use batch-check for speed; optionally protect with timeout if available.
calc_total() {
  git ls-files -z \
  | tr '\0' '\n' \
  | git cat-file --batch-check='%(objectsize)' --stdin \
  | awk '{s+=$1} END{printf "%.0f\n", s+0}'
}

TOTAL_BYTES=""

if command -v timeout >/dev/null 2>&1; then
  # 20 seconds guard to avoid hanging forever
  if TOTAL_BYTES="$(timeout 20s bash -lc 'calc_total' 2>/dev/null)"; then
    :
  else
    echo "WARN: size calc timed out; printing partial diagnostics and falling back."
    TOTAL_BYTES=""
  fi
else
  # No timeout in environment; run directly
  TOTAL_BYTES="$(calc_total 2>/dev/null || true)"
fi

if [ -z "${TOTAL_BYTES:-}" ]; then
  echo "tracked_total_bytes: (FAILED_TO_CALCULATE)"
else
  echo "tracked_total_bytes: $TOTAL_BYTES"
  python - <<'PY' "$TOTAL_BYTES"
import sys
b=int(sys.argv[1])
units=["B","KB","MB","GB","TB"]
u=0
x=float(b)
while x>=1024 and u<len(units)-1:
    x/=1024.0
    u+=1
print(f"tracked_total_human: {x:.2f} {units[u]}")
PY
fi
echo

echo ">>> 2) Top 30 largest tracked files (fast)"
# Get object sizes for each file fast (path<TAB>size), sort desc
git ls-files -z \
| tr '\0' '\n' \
| while IFS= read -r f; do
    # Using git cat-file on path is OK here; list is limited by sort/head later.
    s="$(git cat-file -s "HEAD:$f" 2>/dev/null || echo 0)"
    printf "%12d\t%s\n" "$s" "$f"
  done \
| sort -nr \
| head -n 30 \
| awk '
function hr(x,  u){
  split("B KB MB GB TB",a," ")
  u=1
  while(x>=1024 && u<5){x/=1024;u++}
  return sprintf("%.2f %s", x, a[u])
}
{ printf "%-10s  %s\n", hr($1), $2 }
'
echo

echo ">>> 3) Sanity: tracked node_modules?"
if git ls-files | grep -qE '^frontend/node_modules/'; then
  echo "WARN: tracked node_modules detected!"
  git ls-files | grep -E '^frontend/node_modules/' | head -n 30
else
  echo "OK: no tracked node_modules"
fi
echo

echo ">>> 4) Local .git object DB size (history impact)"
git count-objects -vH || true
echo

echo "DONE: STATION_041B_GITHUB_SIZE_AUDIT_FAST"
echo "=============================================="
