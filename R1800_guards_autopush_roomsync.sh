#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT_ID="1800"
MODE="${1:-PROD}"

echo ">>> [R${ROOT_ID}] Guards + Autopush + RoomsSync (mode=${MODE})"

mkdir -p station_meta/{guards,tree,bindings,rooms,locks,stage_reports} scripts/{guards,ops,rooms,tree_authority}

# ------------------------------------------------------------
# 0) Guard policies (truth)
# ------------------------------------------------------------
cat > station_meta/guards/policy.json << 'JSON'
{
  "version": "0.1.0",
  "require_tree_fresh_seconds": 600,
  "require_rooms_broadcast": true,
  "block_heavy_build_deps": true,
  "blocked_markers": ["maturin", "rust", "pydantic-core", "watchfiles"],
  "allowed_modes": ["TRIAL-1", "TRIAL-2", "TRIAL-3", "PROD"]
}
JSON

# ------------------------------------------------------------
# 1) Tree stamp writer (called from tree_update or guards)
# ------------------------------------------------------------
cat > scripts/tree_authority/tree_stamp.sh << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
ROOT="$HOME/station_root"
TS="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
EPOCH="$(date -u +%s)"
mkdir -p "$ROOT/station_meta/tree"
echo "$TS" > "$ROOT/station_meta/tree/last_tree_update_utc.txt"
echo "$EPOCH" > "$ROOT/station_meta/tree/last_tree_update_epoch.txt"
EOF
chmod +x scripts/tree_authority/tree_stamp.sh

# ------------------------------------------------------------
# 2) Guard: require tree fresh
# ------------------------------------------------------------
cat > scripts/guards/guard_tree_fresh.sh << 'EOF'
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
EOF
chmod +x scripts/guards/guard_tree_fresh.sh

# ------------------------------------------------------------
# 3) Guard: require rooms broadcast
# ------------------------------------------------------------
cat > scripts/guards/guard_rooms_broadcast.sh << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="$HOME/station_root"
POL="$ROOT/station_meta/guards/policy.json"
[ -f "$POL" ] || { echo "GUARD_POLICY_MISSING"; exit 20; }

REQ="$(python - << 'PY'
import json,os
p=os.path.expanduser("~/station_root/station_meta/guards/policy.json")
print(bool(json.load(open(p,"r",encoding="utf-8"))["require_rooms_broadcast"]))
PY
)"

if [ "$REQ" != "True" ]; then
  echo ">>> [guard_rooms_broadcast] SKIP by policy"
  exit 0
fi

LB="$ROOT/station_meta/rooms/last_broadcast.txt"
[ -f "$LB" ] || { echo "GUARD_ROOMS_BROADCAST_MISSING: run rooms_broadcast"; exit 21; }

echo ">>> [guard_rooms_broadcast] OK"
EOF
chmod +x scripts/guards/guard_rooms_broadcast.sh

# ------------------------------------------------------------
# 4) Guard: block heavy build deps in backend requirements
# ------------------------------------------------------------
cat > scripts/guards/guard_termux_safe_deps.sh << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="$HOME/station_root"
POL="$ROOT/station_meta/guards/policy.json"
REQF="$ROOT/backend/requirements.txt"

[ -f "$POL" ] || { echo "GUARD_POLICY_MISSING"; exit 30; }
[ -f "$REQF" ] || { echo "BACKEND_REQUIREMENTS_MISSING"; exit 31; }

BLOCK="$(python - << 'PY'
import json,os
p=os.path.expanduser("~/station_root/station_meta/guards/policy.json")
j=json.load(open(p,"r",encoding="utf-8"))
print(" ".join(j.get("blocked_markers",[])))
PY
)"

FOUND=0
for m in $BLOCK; do
  if grep -qi "$m" "$REQF"; then
    echo "GUARD_BLOCKED_DEP_FOUND marker=$m in backend/requirements.txt"
    FOUND=1
  fi
done

if [ "$FOUND" -ne 0 ]; then
  echo "Action: remove blocked deps OR pin Termux-safe alternatives."
  exit 32
fi

echo ">>> [guard_termux_safe_deps] OK"
EOF
chmod +x scripts/guards/guard_termux_safe_deps.sh

# ------------------------------------------------------------
# 5) Root-tagging guard: enforce Root-ID in commit messages for Dynamo stage pushes
#    (We do not modify git itself; we enforce our own stage_commit_push usage.)
# ------------------------------------------------------------
cat > scripts/guards/guard_root_id_arg.sh << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
RID="${1:-}"
[ -n "$RID" ] || { echo "GUARD_ROOT_ID_MISSING"; exit 40; }
echo "$RID" | grep -Eq '^[0-9]+$' || { echo "GUARD_ROOT_ID_NOT_NUMERIC"; exit 41; }
echo ">>> [guard_root_id_arg] OK root_id=$RID"
EOF
chmod +x scripts/guards/guard_root_id_arg.sh

# ------------------------------------------------------------
# 6) Add a safe wrapper for stage/commit/push that ALWAYS embeds Root-ID
# ------------------------------------------------------------
cat > scripts/ops/autopush_by_root.sh << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

RID="${1:-}"; shift || true
MSG="${1:-}"; shift || true

bash scripts/guards/guard_root_id_arg.sh "$RID"

if [ -z "$MSG" ]; then
  MSG="[R${RID}] autopush"
fi

bash scripts/ops/stage_commit_push.sh "$RID" "$MSG"
EOF
chmod +x scripts/ops/autopush_by_root.sh

# ------------------------------------------------------------
# 7) Patch Dynamo pipelines: add preflight_guards + plan_progression
# ------------------------------------------------------------
python - << 'PY'
import json, os
ROOT=os.path.expanduser("~/station_root")
cfg_path=os.path.join(ROOT,"station_meta","dynamo","dynamo_config.json")
cfg=json.load(open(cfg_path,"r",encoding="utf-8"))

pipes=cfg.setdefault("pipelines", {})

pipes["preflight_guards"] = [
  {"name":"guard_tree_fresh","cmd":"bash scripts/guards/guard_tree_fresh.sh"},
  {"name":"rooms_broadcast","cmd":"bash scripts/rooms/rooms_broadcast.sh"},
  {"name":"guard_rooms_broadcast","cmd":"bash scripts/guards/guard_rooms_broadcast.sh"},
  {"name":"guard_termux_safe_deps","cmd":"bash scripts/guards/guard_termux_safe_deps.sh"}
]

pipes["plan_progression"] = [
  {"name":"preflight_guards","cmd":"bash -lc 'python scripts/ops/dynamo.py PROD preflight_guards 9001'"},
  {"name":"integrate_report","cmd":"bash scripts/ops/integrate_report.sh"}
]

json.dump(cfg, open(cfg_path,"w",encoding="utf-8"), ensure_ascii=False, indent=2)
print(">>> [R1800] pipelines patched: preflight_guards, plan_progression")
PY

# ------------------------------------------------------------
# 8) Autopush this stage
# ------------------------------------------------------------
bash scripts/ops/autopush_by_root.sh "${ROOT_ID}" "[${MODE}] R${ROOT_ID} Guards + RoomsSync + Autopush"
echo ">>> [R${ROOT_ID}] DONE"

echo "Next (plan path, no server run):"
echo "  bash scripts/ops/st.sh dynamo start ${MODE} bootstrap_validate 1000"
echo "  bash scripts/ops/st.sh dynamo start ${MODE} preflight_guards 1800"
echo "  bash scripts/ops/st.sh dynamo start ${MODE} agent_validate 3000"
echo "  bash scripts/ops/st.sh dynamo start ${MODE} frontend_build_check 4000"
echo "  bash scripts/ops/st.sh dynamo start ${MODE} plan_progression 1900"
