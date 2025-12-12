#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="$HOME/station_root"
TS="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
OUT="$ROOT/station_meta/integrate/integrate_${TS}.txt"

echo "INTEGRATE REPORT" > "$OUT"
echo "ts=$TS" >> "$OUT"
echo "" >> "$OUT"

echo "Tree head:" >> "$OUT"
head -n 25 "$ROOT/station_meta/tree/tree_paths.txt" >> "$OUT" || true
echo "" >> "$OUT"

echo "Bindings keys count:" >> "$OUT"
python - << 'PY' >> "$OUT"
import json, os
ROOT=os.path.expanduser("~/station_root")
p=os.path.join(ROOT,"station_meta","bindings","bindings.json")
try:
    j=json.load(open(p,"r",encoding="utf-8"))
    print(len(j.keys()))
except Exception as e:
    print("ERR", e)
PY

echo "" >> "$OUT"
echo "Rooms present:" >> "$OUT"
ls -1 "$ROOT/station_meta/rooms" >> "$OUT" 2>/dev/null || true

echo ">>> [integrate_report] wrote $OUT"
