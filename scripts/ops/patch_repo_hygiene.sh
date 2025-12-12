#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
cd "$(cd "$(dirname "$0")/../.." && pwd)"

# 1) Ensure dirs exist
mkdir -p station_logs station_meta/{locks,stage_reports,queue,dynamo,tree,bindings}

# 2) .gitignore: ignore runtime noise
if [ ! -f .gitignore ]; then : > .gitignore; fi

grep -q "### STATION RUNTIME" .gitignore 2>/dev/null || cat >> .gitignore <<'EOF'

### STATION RUNTIME (ignore)
station_logs/
backend.log
frontend.log
station_meta/locks/
station_meta/dynamo/backend.pid
station_meta/stage_reports/*.json
station_meta/dynamo/events.jsonl
station_meta/queue/tasks.jsonl

# Python
__pycache__/
*.pyc
backend/.venv/

# Node
frontend/node_modules/
frontend/dist/
frontend/.vite/
EOF

# 3) Remove tracked runtime files if already tracked
git rm -r --cached station_meta/locks 2>/dev/null || true
git rm --cached station_meta/dynamo/backend.pid 2>/dev/null || true
git rm --cached station_meta/dynamo/events.jsonl 2>/dev/null || true
git rm --cached station_meta/queue/tasks.jsonl 2>/dev/null || true
git rm --cached station_meta/stage_reports/*.json 2>/dev/null || true
git rm --cached station_logs 2>/dev/null || true
git rm --cached backend.log frontend.log 2>/dev/null || true

echo ">>> [patch_repo_hygiene] done"
