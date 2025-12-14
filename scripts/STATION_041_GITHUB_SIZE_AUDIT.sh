#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="${STATION_ROOT:-$HOME/station_root}"
cd "$ROOT"

echo "=============================================="
echo "STATION_041_GITHUB_SIZE_AUDIT"
echo "root: $ROOT"
date
echo "=============================================="
echo

# Must be git repo
if [ ! -d .git ]; then
  echo "ERROR: Not a git repo (.git missing) in: $ROOT"
  exit 1
fi

echo ">>> 0) Repo identity"
echo "branch: $(git branch --show-current || true)"
echo "HEAD:   $(git rev-parse --short HEAD)"
echo

echo ">>> 1) Total tracked bytes (this is what you actually push to GitHub)"
# Sum of blob sizes for all tracked files at HEAD
TOTAL_BYTES="$(
  git ls-files -z \
  | xargs -0 -n1 git cat-file -s 2>/dev/null \
  | awk '{s+=$1} END{printf "%.0f\n", s+0}'
)"
echo "tracked_total_bytes: $TOTAL_BYTES"
echo

echo ">>> 2) Human readable"
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
echo

echo ">>> 3) Top 30 largest tracked files"
# list: size<TAB>path then sort desc
git ls-files -z \
| while IFS= read -r -d '' f; do
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

echo ">>> 4) Quick sanity: any tracked node_modules?"
if git ls-files | grep -qE '^frontend/node_modules/'; then
  echo "WARN: tracked node_modules detected!"
  git ls-files | grep -E '^frontend/node_modules/' | head -n 20
else
  echo "OK: no tracked node_modules"
fi
echo

echo ">>> 5) Git object database size (local) (not equal to GitHub, but useful)"
# This shows local .git pack/objects size; can be bigger than tracked files due to history.
git count-objects -vH || true
echo

echo "DONE: STATION_041_GITHUB_SIZE_AUDIT"
echo "=============================================="
