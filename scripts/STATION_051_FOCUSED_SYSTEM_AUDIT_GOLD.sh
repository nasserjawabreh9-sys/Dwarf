#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="${STATION_ROOT:-$HOME/station_root}"
cd "$ROOT"

echo "===================================================="
echo "STATION_051_FOCUSED_SYSTEM_AUDIT_GOLD"
echo "root: $ROOT"
date
echo "===================================================="
echo

# ---- helper: find excluding noise
FIND_CLEAN() {
  # usage: FIND_CLEAN <find args...>
  find . \
    -path "./.git" -prune -o \
    -path "./backend/.venv" -prune -o \
    -path "./frontend/node_modules" -prune -o \
    -path "./frontend/dist" -prune -o \
    -path "./frontend/build" -prune -o \
    -path "./station_logs" -prune -o \
    -path "./global/logs" -prune -o \
    -name "__pycache__" -prune -o \
    "$@"
}

# ----------------------------------------------------
# 0) Repo identity
# ----------------------------------------------------
echo ">>> [0] Repo identity"
if [ -d .git ]; then
  echo "git: OK"
  echo "branch: $(git branch --show-current || echo '-')"
  echo "HEAD:   $(git rev-parse --short HEAD || echo '-')"
else
  echo "git: MISSING"
fi
echo

# ----------------------------------------------------
# 1) Dynamo / Loop real files (project only)
# ----------------------------------------------------
echo ">>> [1] Dynamo / Loop (project-only, no .venv)"
LOOP_LIST="$(FIND_CLEAN -type f \( -iname "*dynamo*" -o -iname "*loop*" \) -print)"
LOOP_COUNT="$(printf "%s\n" "$LOOP_LIST" | sed '/^$/d' | wc -l | tr -d ' ')"
echo "loop_related_files_count_clean: $LOOP_COUNT"
printf "%s\n" "$LOOP_LIST" | sed '/^$/d' | head -n 50 | sed 's/^/  - /'
echo

# ----------------------------------------------------
# 2) Agent / AI / LLM real files (project only)
# ----------------------------------------------------
echo ">>> [2] Agent / AI / LLM (project-only, no .venv)"
AGENT_LIST="$(FIND_CLEAN -type f \( -iname "*agent*" -o -iname "*llm*" -o -iname "*ai*" \) -print)"
AGENT_COUNT="$(printf "%s\n" "$AGENT_LIST" | sed '/^$/d' | wc -l | tr -d ' ')"
echo "agent_ai_files_count_clean: $AGENT_COUNT"
printf "%s\n" "$AGENT_LIST" | sed '/^$/d' | head -n 50 | sed 's/^/  - /'
echo

# ----------------------------------------------------
# 3) Rooms / Concurrency / Queue real files
# ----------------------------------------------------
echo ">>> [3] Rooms / Concurrency / Queues (project-only)"
ROOM_LIST="$(FIND_CLEAN -type f \( -iname "*room*" -o -iname "*queue*" -o -iname "*concurr*" \) -print)"
ROOM_COUNT="$(printf "%s\n" "$ROOM_LIST" | sed '/^$/d' | wc -l | tr -d ' ')"
echo "rooms_queue_files_count_clean: $ROOM_COUNT"
printf "%s\n" "$ROOM_LIST" | sed '/^$/d' | head -n 50 | sed 's/^/  - /'
echo

# ----------------------------------------------------
# 4) Quick endpoint grep (FastAPI routes)
# ----------------------------------------------------
echo ">>> [4] Endpoint grep (FastAPI routes signatures)"
PY_LIST="$(FIND_CLEAN -type f -iname "*.py" -print)"
echo "python_files_clean: $(printf "%s\n" "$PY_LIST" | sed '/^$/d' | wc -l | tr -d ' ')"

echo
echo "---- likely route defs (get/post/put/delete) mentioning: dynamo|loop|agent|rooms|queue"
# Grep only in python files (project)
printf "%s\n" "$PY_LIST" | sed '/^$/d' | while IFS= read -r f; do
  grep -nE "(app\.(get|post|put|delete)\(|router\.(get|post|put|delete)\()" "$f" 2>/dev/null \
    | grep -iE "dynamo|loop|agent|room|queue" \
    | sed "s|^|$f:|" \
    || true
done | head -n 120

echo
echo "---- key imports / modules present?"
for target in \
  "backend/app/dynamo_core.py" \
  "backend/app/loop_queue.py" \
  "backend/app/loop_worker.py" \
  "backend/app/routes/dynamo.py" \
  "backend/app/routes/loop.py" \
  "backend/app/routers/dynamo.py" \
  "backend/app/state/dynamo.py"
do
  if [ -f "$target" ]; then
    echo "OK: $target"
  else
    echo "MISSING: $target"
  fi
done
echo

# ----------------------------------------------------
# 5) Runtime check (try common ports)
# ----------------------------------------------------
echo ">>> [5] Runtime check (healthz on common ports)"
for p in 8000 8010 8080 8787; do
  if curl -fsS "http://127.0.0.1:${p}/healthz" >/dev/null 2>&1; then
    echo "backend_up: YES on port $p"
    echo "healthz:"
    curl -fsS "http://127.0.0.1:${p}/healthz" || true
    echo
    break
  else
    echo "backend_up: NO on port $p"
  fi
done
echo

# ----------------------------------------------------
# 6) Reality summary (clean)
# ----------------------------------------------------
echo ">>> [6] Reality summary (clean)"
echo "files_total_clean: $(FIND_CLEAN -type f -print | wc -l | tr -d ' ')"
echo "shell_scripts_clean: $(FIND_CLEAN -type f -iname '*.sh' -print | wc -l | tr -d ' ')"
echo "db_files_clean: $(FIND_CLEAN -type f \( -iname '*.db' -o -iname '*.sqlite*' \) -print | wc -l | tr -d ' ')"
echo
echo "===================================================="
echo "DONE: STATION_051_FOCUSED_SYSTEM_AUDIT_GOLD"
echo "===================================================="
