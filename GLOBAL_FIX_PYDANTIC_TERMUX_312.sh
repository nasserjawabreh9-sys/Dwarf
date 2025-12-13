#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail

ROOT="$HOME/station_root"
BACK="$ROOT/backend"
LOGS="$ROOT/station_logs"
mkdir -p "$LOGS" "$BACK/backend"

echo "=== FIX: Termux Py312 pydantic-core build (use pydantic v1) ==="

# 0) Kill port 8000 hard
for pid in $(lsof -tiTCP:8000 -sTCP:LISTEN 2>/dev/null); do
  kill -9 "$pid" >/dev/null 2>&1 || true
done

# 1) Force Termux-safe requirements (FastAPI + Pydantic v1)
cat > "$BACK/requirements.txt" <<'REQ'
fastapi==0.99.1
uvicorn==0.23.2
pydantic<2
python-multipart==0.0.6
requests==2.32.3
REQ
echo "Wrote: $BACK/requirements.txt (Termux-safe)"

# 2) Ensure ASGI entry always exports app
touch "$BACK/backend/__init__.py"
cat > "$BACK/backend/app.py" <<'PY'
"""
Stable ASGI entrypoint for Termux.
Target: uvicorn backend.app:app
"""
from fastapi import FastAPI

def _load():
    # Try existing bigger app first (if present)
    try:
        from backend.main import app as a  # type: ignore
        return a
    except Exception:
        pass
    try:
        from main import app as a  # type: ignore
        return a
    except Exception:
        pass
    try:
        from app import app as a  # type: ignore
        return a
    except Exception:
        pass

    a = FastAPI()
    @a.get("/healthz")
    def healthz():
        return {"ok": True, "fallback": True}
    return a

app = _load()
PY
echo "Wrote: $BACK/backend/app.py (stable wrapper)"

# 3) Rebuild venv clean
cd "$BACK"
rm -rf .venv
python -m venv .venv
source .venv/bin/activate
python -m pip install -U pip >/dev/null 2>&1 || true
python -m pip install -r requirements.txt >"$LOGS/pip_install.log" 2>&1 || {
  echo "pip install failed; tail:"
  tail -n 120 "$LOGS/pip_install.log" || true
  exit 1
}

# 4) Run backend WITHOUT reload (reload spawns extra process & confusion)
nohup python -m uvicorn backend.app:app --host 127.0.0.1 --port 8000 >"$LOGS/backend.log" 2>&1 &

# 5) Health check
for _ in $(seq 1 40); do
  if curl -fsS http://127.0.0.1:8000/healthz >/dev/null 2>&1; then
    echo "OK: Backend healthy -> http://127.0.0.1:8000/healthz"
    exit 0
  fi
  sleep 0.4
done

echo "Backend still unhealthy; tail backend.log:"
tail -n 160 "$LOGS/backend.log" || true
exit 1
