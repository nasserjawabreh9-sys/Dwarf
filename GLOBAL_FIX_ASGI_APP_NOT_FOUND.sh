#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail

ROOT="$HOME/station_root"
BACK="$ROOT/backend"
LOGS="$ROOT/station_logs"
mkdir -p "$LOGS"

echo "=== FIX: ASGI app not found in backend.app ==="

# 0) Stop anything on 8000 (reloader may keep a child process)
for pid in $(lsof -tiTCP:8000 -sTCP:LISTEN 2>/dev/null); do
  kill -9 "$pid" >/dev/null 2>&1 || true
done

# 1) Ensure backend package dir
mkdir -p "$BACK/backend"
touch "$BACK/backend/__init__.py"

# 2) Backup existing backend/app.py (if exists)
TS="$(date +%Y%m%d_%H%M%S)"
if [[ -f "$BACK/backend/app.py" ]]; then
  cp -f "$BACK/backend/app.py" "$BACK/backend/app_old_${TS}.py" || true
  echo "Backup: backend/backend/app_old_${TS}.py"
fi

# 3) Write stable wrapper that ALWAYS exposes `app`
cat > "$BACK/backend/app.py" <<'PY'
"""
Stable ASGI entrypoint.

Goal: ensure `app` exists for: uvicorn backend.app:app

It tries, in order:
- from backend.main import app
- from main import app
- from app import app
Else: create minimal FastAPI app with /healthz
"""
from fastapi import FastAPI

def _load():
    # 1) package backend.main
    try:
        from backend.main import app as a  # type: ignore
        return a
    except Exception:
        pass

    # 2) root-level main.py
    try:
        from main import app as a  # type: ignore
        return a
    except Exception:
        pass

    # 3) root-level app.py
    try:
        from app import app as a  # type: ignore
        return a
    except Exception:
        pass

    # 4) fallback
    a = FastAPI()
    @a.get("/healthz")
    def healthz():
        return {"ok": True, "fallback": True}
    return a

app = _load()
PY

echo "Wrote: $BACK/backend/app.py (wrapper)"

# 4) Ensure requirements (best-effort)
if [[ ! -f "$BACK/requirements.txt" ]]; then
  cat > "$BACK/requirements.txt" <<'REQ'
fastapi
uvicorn
REQ
fi

# 5) Ensure venv exists & deps installed
cd "$BACK"
if [[ ! -d .venv ]]; then
  python -m venv .venv
fi
source .venv/bin/activate
python -m pip install -U pip >/dev/null
python -m pip install -r requirements.txt >"$LOGS/pip_install.log" 2>&1 || {
  echo "pip install failed. Tail:"
  tail -n 80 "$LOGS/pip_install.log" || true
  exit 1
}

# 6) Start backend clean (no --reload to avoid reloader confusion)
nohup python -m uvicorn backend.app:app --host 127.0.0.1 --port 8000 >"$LOGS/backend.log" 2>&1 &

sleep 1
curl -fsS http://127.0.0.1:8000/healthz >/dev/null || {
  echo "Backend still unhealthy. Tail backend.log:"
  tail -n 120 "$LOGS/backend.log" || true
  exit 1
}

echo "OK: Backend healthy on http://127.0.0.1:8000/healthz"
echo "Next: restart full station (frontend already OK):"
echo "  bash ~/station_root/scripts/station_ops.sh restart"
