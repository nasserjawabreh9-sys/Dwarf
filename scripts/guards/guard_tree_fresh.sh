#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="$HOME/station_root"
POL="$ROOT/station_meta/guards/policy.json"
[ -f "$POL" ] || { echo "GUARD_POLICY_MISSING"; exit 10; }

REQ="$(python - << 'PY'
import json,os
p=os.path.expanduser("~/station_root/station_meta/guards/policy.json")
print(int(json.load(open(p,"r",encoding="utf-8"))["require_tree_fresh_seconds"]))
PY
)"

STAMP_E="$ROOT/station_meta/tree/last_tree_update_epoch.txt"
TREE_P="$ROOT/station_meta/tree/tree_paths.txt"

[ -f "$TREE_P" ] || { echo "GUARD_TREE_MISSING: run bootstrap_validate"; exit 11; }
[ -f "$STAMP_E" ] || { echo "GUARD_STAMP_MISSING: run bootstrap_validate"; exit 12; }

NOW="$(date -u +%s)"
LAST="$(cat "$STAMP_E" | tr -d '\r\n' || true)"
[ -n "$LAST" ] || { echo "GUARD_STAMP_EMPTY"; exit 13; }

AGE=$(( NOW - LAST ))
if [ "$AGE" -gt "$REQ" ]; then
  echo "GUARD_TREE_STALE age_seconds=$AGE limit=$REQ"
  echo "Action: run => bash scripts/ops/st.sh dynamo start PROD bootstrap_validate 1000"
  exit 14
fi

echo ">>> [guard_tree_fresh] OK age_seconds=$AGE"
