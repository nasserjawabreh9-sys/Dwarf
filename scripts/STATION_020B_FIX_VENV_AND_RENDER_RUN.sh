#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="${STATION_ROOT:-$HOME/station_root}"
BACK="$ROOT/backend"

echo "=== [STATION_020B] Fix venv + render run ==="
echo "ROOT=$ROOT"
echo "BACK=$BACK"
echo

cd "$BACK"

# 1) Detect Python from venv (preferred) or fallback
PY=""
if [ -x "$BACK/.venv/bin/python" ]; then
  PY="$BACK/.venv/bin/python"
elif [ -x "$BACK/venv/bin/python" ]; then
  PY="$BACK/venv/bin/python"
else
  PY="$(command -v python3 || command -v python || true)"
fi

if [ -z "$PY" ]; then
  echo "ERROR: python not found"
  exit 1
fi

echo "Using PY=$PY"
echo

# 2) Ensure requirements exist and include FastAPI + Uvicorn
REQ=""
if [ -f "$BACK/requirements.txt" ]; then
  REQ="$BACK/requirements.txt"
elif [ -f "$BACK/requirements-prod.txt" ]; then
  REQ="$BACK/requirements-prod.txt"
fi

if [ -z "$REQ" ]; then
  echo "WARN: No requirements file found. Creating backend/requirements.txt"
  REQ="$BACK/requirements.txt"
  cat > "$REQ" <<'REQTXT'
fastapi>=0.110
uvicorn[standard]>=0.24
pydantic>=2.5
python-multipart>=0.0.9
REQTXT
fi

# Append if missing (idempotent-ish)
grep -qi '^fastapi' "$REQ" || echo 'fastapi>=0.110' >> "$REQ"
grep -qi '^uvicorn' "$REQ" || echo 'uvicorn[standard]>=0.24' >> "$REQ"

echo "Requirements file: $REQ"
echo "Top lines:"
head -n 30 "$REQ" || true
echo

# 3) Install deps into the same PY env (safe even if already installed)
echo ">>> Installing backend deps into detected env..."
"$PY" -m pip install -U pip setuptools wheel >/dev/null
"$PY" -m pip install -r "$REQ"
echo "OK: deps installed"
echo

# 4) Detect FastAPI entry again (same heuristic)
CAND="$(grep -RIl --exclude-dir=.venv --exclude-dir=venv --exclude-dir=node_modules --exclude-dir=dist --exclude-dir=build \
  "FastAPI(" "$BACK" 2>/dev/null | head -n 1 || true)"

if [ -z "${CAND:-}" ]; then
  echo "ERROR: Could not find a FastAPI entry file."
  exit 1
fi

REL="${CAND#$BACK/}"
MOD="${REL%.py}"
MOD="${MOD//\//.}"

APPVAR="app"
if grep -qE '^[[:space:]]*application[[:space:]]*=' "$CAND"; then
  APPVAR="application"
fi

echo "Detected FastAPI file: $CAND"
echo "Uvicorn target: ${MOD}:${APPVAR}"
echo

# 5) Import test WITH SAME PY
echo ">>> Import test using the same env..."
"$PY" - <<PY
import importlib
m = "${MOD}"
print("Importing:", m)
importlib.import_module(m)
print("OK: Import succeeded")
PY
echo

# 6) Create Render run script that uses python -m uvicorn (more reliable)
mkdir -p "$BACK/ops"
cat > "$BACK/ops/run_render.sh" <<EOF
#!/usr/bin/env bash
set -euo pipefail

: "\${PORT:=8000}"
: "\${STATION_ENV:=prod}"

# Prefer venv python if exists (Render might not use venv, but this is fine)
if [ -x "\$(pwd)/.venv/bin/python" ]; then
  PY="\$(pwd)/.venv/bin/python"
elif [ -x "\$(pwd)/venv/bin/python" ]; then
  PY="\$(pwd)/venv/bin/python"
else
  PY="python3"
fi

echo ">>> [RUN_RENDER] STATION_ENV=\$STATION_ENV PORT=\$PORT PY=\$PY"
exec "\$PY" -m uvicorn ${MOD}:${APPVAR} --host 0.0.0.0 --port "\$PORT"
EOF
chmod +x "$BACK/ops/run_render.sh"

echo "Created/Updated: $BACK/ops/run_render.sh"
echo
echo "DONE."
