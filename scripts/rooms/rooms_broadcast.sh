#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="$HOME/station_root"
TS="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

ROOMS_JSON="$ROOT/station_meta/concurrency/rooms.json"
TREE="$ROOT/station_meta/tree/tree_paths.txt"
BIND="$ROOT/station_meta/bindings/bindings.json"

[ -f "$ROOMS_JSON" ] || { echo "rooms.json missing"; exit 2; }
[ -f "$TREE" ] || { echo "tree_paths.txt missing. run bootstrap_validate first"; exit 3; }
[ -f "$BIND" ] || { echo "bindings.json missing. run bootstrap_validate first"; exit 4; }

python - << 'PY'
import json, os, shutil
ROOT=os.path.expanduser("~/station_root")
rooms=json.load(open(os.path.join(ROOT,"station_meta","concurrency","rooms.json"),"r",encoding="utf-8"))["rooms"]
src_tree=os.path.join(ROOT,"station_meta","tree","tree_paths.txt")
src_bind=os.path.join(ROOT,"station_meta","bindings","bindings.json")

for rk in rooms.keys():
    dst=os.path.join(ROOT,"station_meta","rooms",rk)
    os.makedirs(dst, exist_ok=True)
    shutil.copy2(src_tree, os.path.join(dst,"tree_paths.txt"))
    shutil.copy2(src_bind, os.path.join(dst,"bindings.json"))
print(">>> [rooms_broadcast] OK rooms_count=", len(rooms))
PY

echo "ts=${TS}" > "$ROOT/station_meta/rooms/last_broadcast.txt"
echo ">>> [rooms_broadcast] wrote station_meta/rooms/* + last_broadcast.txt"
