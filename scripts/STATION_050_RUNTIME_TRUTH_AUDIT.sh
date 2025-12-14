#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="${STATION_ROOT:-$HOME/station_root}"
cd "$ROOT"

echo "===================================================="
echo "STATION_050_RUNTIME_TRUTH_AUDIT"
echo "root: $ROOT"
date
echo "===================================================="
echo

# ----------------------------------------------------
# 0) Repo & Runtime
# ----------------------------------------------------
echo ">>> [0] Repo & Runtime"
if [ -d .git ]; then
  echo "git: OK"
  echo "branch: $(git branch --show-current || echo '-')"
  echo "HEAD:   $(git rev-parse --short HEAD || echo '-')"
else
  echo "git: MISSING"
fi
echo "python: $(python --version 2>/dev/null || echo 'N/A')"
echo

# ----------------------------------------------------
# 1) Dynamo / Loops
# ----------------------------------------------------
echo ">>> [1] Dynamo / Loops"
LOOP_FILES=$(find . -type f \( \
  -iname "*loop*" -o \
  -iname "*dynamo*" \
\) | wc -l | tr -d ' ')

echo "loop_related_files_count: $LOOP_FILES"

find . -type f \( -iname "*loop*" -o -iname "*dynamo*" \) \
  | head -n 20 | sed 's/^/  - /'

echo

# ----------------------------------------------------
# 2) Agent / AI Core
# ----------------------------------------------------
echo ">>> [2] Agent / AI Core"
AGENT_FILES=$(find . -type f \( \
  -iname "*agent*" -o \
  -iname "*ai*" -o \
  -iname "*llm*" \
\) | wc -l | tr -d ' ')

echo "agent_ai_files_count: $AGENT_FILES"

find . -type f \( -iname "*agent*" -o -iname "*ai*" -o -iname "*llm*" \) \
  | head -n 20 | sed 's/^/  - /'

echo

# ----------------------------------------------------
# 3) Rooms / Concurrency / Queues
# ----------------------------------------------------
echo ">>> [3] Rooms / Concurrency / Queues"
ROOM_FILES=$(find . -type f \( \
  -iname "*room*" -o \
  -iname "*queue*" -o \
  -iname "*concurr*" \
\) | wc -l | tr -d ' ')

echo "rooms_queue_files_count: $ROOM_FILES"

find . -type f \( -iname "*room*" -o -iname "*queue*" -o -iname "*concurr*" \) \
  | head -n 20 | sed 's/^/  - /'

echo

# ----------------------------------------------------
# 4) Termux-like Engine (Shell / Ops / One-click)
# ----------------------------------------------------
echo ">>> [4] Termux-like Engine / Ops"
SHELL_FILES=$(find . -type f -iname "*.sh" | wc -l | tr -d ' ')
echo "shell_scripts_count: $SHELL_FILES"

find . -type f -iname "*.sh" | head -n 20 | sed 's/^/  - /'
echo

# ----------------------------------------------------
# 5) Operational Fingerprint (Your Operational Style)
# ----------------------------------------------------
echo ">>> [5] Operational Fingerprint"
grep -R --line-number -E \
  "ONE_SHOT|AUTO|DYNAMO|LOOP|FACTORY|ROYAL|GUARD|HARDEN|ULTRA" \
  . 2>/dev/null | head -n 20 | sed 's/^/  - /'

echo

# ----------------------------------------------------
# 6) Live Runtime Signals (if backend running)
# ----------------------------------------------------
echo ">>> [6] Live Runtime Signals"
if curl -fsS http://127.0.0.1:8010/healthz >/dev/null 2>&1; then
  echo "backend: RUNNING on :8010"
  echo "healthz:"
  curl -fsS http://127.0.0.1:8010/healthz || true
else
  echo "backend: NOT RUNNING (or different port)"
fi
echo

# ----------------------------------------------------
# 7) Reality Check (Not Echo)
# ----------------------------------------------------
echo ">>> [7] Reality Check"
echo "files_total: $(find . -type f | wc -l | tr -d ' ')"
echo "python_files: $(find . -type f -iname '*.py' | wc -l | tr -d ' ')"
echo "shell_files:  $(find . -type f -iname '*.sh' | wc -l | tr -d ' ')"
echo "db_files:     $(find . -type f \( -iname '*.db' -o -iname '*.sqlite*' \) | wc -l | tr -d ' ')"

echo
echo "===================================================="
echo "DONE: STATION_050_RUNTIME_TRUTH_AUDIT"
echo "===================================================="
