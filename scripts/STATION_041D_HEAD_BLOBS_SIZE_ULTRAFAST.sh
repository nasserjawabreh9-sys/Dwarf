#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
cd "${STATION_ROOT:-$HOME/station_root}"

echo "=============================================="
echo "STATION_041D_HEAD_BLOBS_SIZE_ULTRAFAST"
date
echo "=============================================="
echo

if [ ! -d .git ]; then
  echo "ERROR: Not a git repo"
  exit 1
fi

# This lists blobs in HEAD with their sizes without per-file cat-file calls
TOTAL_BYTES="$(
  git ls-tree -r -l HEAD \
  | awk '{s+=$4} END{printf "%.0f\n", s+0}'
)"

echo "head_tracked_total_bytes: $TOTAL_BYTES"
python - <<'PY' "$TOTAL_BYTES"
import sys
b=int(sys.argv[1])
units=["B","KB","MB","GB","TB"]
u=0
x=float(b)
while x>=1024 and u<len(units)-1:
    x/=1024.0
    u+=1
print(f"head_tracked_total_human: {x:.2f} {units[u]}")
PY

echo
echo "DONE"
