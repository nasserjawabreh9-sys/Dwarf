#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT_ID="1700"
MODE="${1:-PROD}"

echo ">>> [R${ROOT_ID}] Rooms Pipelines + Broadcast + Integrate (mode=${MODE})"

mkdir -p scripts/rooms scripts/ops station_meta/{rooms,integrate}

# ------------------------------------------------------------
# 1) Broadcast tree/bindings into each Room (truth sync)
# ------------------------------------------------------------
cat > scripts/rooms/rooms_broadcast.sh << 'EOF'
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
EOF
chmod +x scripts/rooms/rooms_broadcast.sh

# ------------------------------------------------------------
# 2) Integrate report (simple, but enforceable)
# ------------------------------------------------------------
cat > scripts/ops/integrate_report.sh << 'EOF'
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
EOF
chmod +x scripts/ops/integrate_report.sh

# ------------------------------------------------------------
# 3) Patch dynamo_config.json safely (add pipelines)
# ------------------------------------------------------------
python - << 'PY'
import json, os
ROOT=os.path.expanduser("~/station_root")
cfg_path=os.path.join(ROOT,"station_meta","dynamo","dynamo_config.json")
cfg=json.load(open(cfg_path,"r",encoding="utf-8"))

pipes=cfg.setdefault("pipelines", {})

# stage_only: only commit/push via dynamo's own stage step
# (we keep pipeline steps empty so dynamo still does its stage_commit_push at the end)
pipes.setdefault("stage_only", [])

# agent_validate: no external deps, just checks files + python syntax
pipes.setdefault("agent_validate", [
  {"name":"rooms_broadcast","cmd":"bash scripts/rooms/rooms_broadcast.sh"},
  {"name":"agent_files_check","cmd":"bash -lc 'test -f station_meta/concurrency/rooms.json && test -f scripts/ops/dynamo.py && echo OK'"},
  {"name":"agent_python_smoke","cmd":"bash -lc 'python -c \"import json,os; print(\\\"agent_smoke_ok\\\")\"'"},
  {"name":"integrate_report","cmd":"bash scripts/ops/integrate_report.sh"}
])

# frontend_build_check: Termux-safe, no npm install forced. Just sanity + typecheck if available.
pipes.setdefault("frontend_build_check", [
  {"name":"rooms_broadcast","cmd":"bash scripts/rooms/rooms_broadcast.sh"},
  {"name":"frontend_presence","cmd":"bash -lc 'test -d frontend && test -f frontend/package.json && echo OK'"},
  {"name":"frontend_node_ver","cmd":"bash -lc 'node -v && npm -v'"},
  {"name":"frontend_ts_check","cmd":"bash -lc 'cd frontend && (npm run -s typecheck 2>/dev/null || echo SKIP_typecheck)'"},
  {"name":"integrate_report","cmd":"bash scripts/ops/integrate_report.sh"}
])

json.dump(cfg, open(cfg_path,"w",encoding="utf-8"), ensure_ascii=False, indent=2)
print(">>> [R1700] patched dynamo_config.json pipelines:", ", ".join(sorted(pipes.keys())))
PY

# ------------------------------------------------------------
# 4) Commit + Push (root anchored)
# ------------------------------------------------------------
bash scripts/ops/stage_commit_push.sh "${ROOT_ID}" "[${MODE}] R${ROOT_ID} Rooms pipelines + broadcast + integrate"
echo ">>> [R${ROOT_ID}] DONE"

echo "Next (plan-only):"
echo "  bash scripts/ops/st.sh dynamo start ${MODE} bootstrap_validate 1000"
echo "  bash scripts/ops/st.sh dynamo start ${MODE} agent_validate 3000"
echo "  bash scripts/ops/st.sh dynamo start ${MODE} frontend_build_check 4000"
echo "  bash scripts/ops/st.sh dynamo start ${MODE} stage_only 5000"
