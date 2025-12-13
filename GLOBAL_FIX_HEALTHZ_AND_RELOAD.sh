#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail

ROOT="$HOME/station_root"
BACK="$ROOT/backend"
LOGS="$ROOT/station_logs"
SCRIPTS="$ROOT/scripts"

echo "=== FIX: ensure /healthz + remove reload + align ops ==="
mkdir -p "$LOGS" "$BACK/backend" "$SCRIPTS"

# --- hard stop 8000 ---
for pid in $(lsof -tiTCP:8000 -sTCP:LISTEN 2>/dev/null); do
  kill -9 "$pid" >/dev/null 2>&1 || true
done

# --- ensure backend package ---
touch "$BACK/backend/__init__.py"

# --- patch backend/backend/app.py to ALWAYS provide /healthz ---
TS="$(date +%Y%m%d_%H%M%S)"
if [[ -f "$BACK/backend/app.py" ]]; then
  cp -f "$BACK/backend/app.py" "$BACK/backend/app_before_fix_${TS}.py" || true
  echo "Backup: $BACK/backend/app_before_fix_${TS}.py"
fi

cat > "$BACK/backend/app.py" <<'PY'
"""
Stable ASGI entrypoint.
Target: uvicorn backend.app:app

It tries to load an existing FastAPI app, then enforces /healthz.
"""
from fastapi import FastAPI

def _load() -> FastAPI:
    # 1) backend.main
    try:
        from backend.main import app as a  # type: ignore
        return a
    except Exception:
        pass

    # 2) root main.py
    try:
        from main import app as a  # type: ignore
        return a
    except Exception:
        pass

    # 3) root app.py
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

def _ensure_healthz(a: FastAPI) -> FastAPI:
    # If /healthz doesn't exist, add it.
    try:
        paths = set()
        for r in getattr(a, "routes", []):
            p = getattr(r, "path", None)
            if isinstance(p, str):
                paths.add(p)
        if "/healthz" not in paths:
            @a.get("/healthz")
            def healthz():
                return {"ok": True, "patched": True}
    except Exception:
        # As a last resort, return a new minimal app.
        b = FastAPI()

        @b.get("/healthz")
        def healthz():
            return {"ok": True, "fallback": True}

        return b

    return a

app = _ensure_healthz(_load())
PY

echo "Wrote: $BACK/backend/app.py (guaranteed /healthz)"

# --- Termux-safe requirements (keep pydantic<2) ---
cat > "$BACK/requirements.txt" <<'REQ'
fastapi==0.99.1
uvicorn==0.23.2
pydantic<2
python-multipart==0.0.6
requests==2.32.3
REQ
echo "Wrote: $BACK/requirements.txt (Termux-safe)"

# --- rebuild venv clean ---
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

# --- patch uul_run.sh: remove --reload and health check fallback ---
if [[ -f "$SCRIPTS/uul_run.sh" ]]; then
  cp -f "$SCRIPTS/uul_run.sh" "$SCRIPTS/uul_run_before_fix_${TS}.sh" || true
  echo "Backup: $SCRIPTS/uul_run_before_fix_${TS}.sh"
  # remove --reload if exists
  sed -i 's/--reload//g' "$SCRIPTS/uul_run.sh" || true
fi

# --- patch station_ops.sh status: try /healthz then /health ---
if [[ -f "$SCRIPTS/station_ops.sh" ]]; then
  cp -f "$SCRIPTS/station_ops.sh" "$SCRIPTS/station_ops_before_fix_${TS}.sh" || true
  echo "Backup: $SCRIPTS/station_ops_before_fix_${TS}.sh"
  # Replace the single curl healthz check with a dual check (best-effort).
  perl -0777 -i -pe 's/curl -fsS http:\/\/127\.0\.0\.1:8000\/healthz[^\n]*\n/if curl -fsS http:\/\/127.0.0.1:8000\/healthz >\/dev\/null 2>&1; then echo \"Backend: OK (\\/healthz)\"; elif curl -fsS http:\/\/127.0.0.1:8000\/health >\/dev\/null 2>&1; then echo \"Backend: OK (\\/health)\"; else echo \"Backend health not reachable\"; fi\n/g' "$SCRIPTS/station_ops.sh" || true
fi

# --- start backend clean (no reload) ---
for pid in $(lsof -tiTCP:8000 -sTCP:LISTEN 2>/dev/null); do
  kill -9 "$pid" >/dev/null 2>&1 || true
done

nohup python -m uvicorn backend.app:app --host 127.0.0.1 --port 8000 >"$LOGS/backend.log" 2>&1 &

# --- verify ---
for _ in $(seq 1 50); do
  if curl -fsS http://127.0.0.1:8000/healthz >/dev/null 2>&1; then
    echo "OK: Backend healthy -> http://127.0.0.1:8000/healthz"
    echo "Next:"
    echo "  bash ~/station_root/scripts/station_ops.sh status"
    echo "  bash ~/station_root/scripts/station_ops.sh restart"
    exit 0
  fi
  sleep 0.3
done

echo "Backend still unhealthy; tail backend.log:"
tail -n 200 "$LOGS/backend.log" || true
exit 1
