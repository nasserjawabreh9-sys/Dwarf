#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="${STATION_ROOT:-$HOME/station_root}"
TARGET="$ROOT/backend/app/main.py"

if [ ! -f "$TARGET" ]; then
  echo "ERROR: missing file: $TARGET"
  exit 1
fi

echo ">>> Patching: $TARGET"

python - <<'PY' "$TARGET"
import sys, re, pathlib, datetime
p = pathlib.Path(sys.argv[1])
s = p.read_text(encoding="utf-8", errors="ignore")

if "/api/status" in s:
    print("SKIP: /api/status already present")
    raise SystemExit(0)

# Ensure we have datetime + os imports (minimal, safe)
if "import os" not in s:
    s = re.sub(r"(^from __future__.*\n)?", lambda m: (m.group(0) or "") + "import os\n", s, count=1, flags=re.M)

if "import datetime" not in s and "from datetime import" not in s:
    s = re.sub(r"import os\n", "import os\nimport datetime\n", s, count=1)

# Find a good insertion point: after app = FastAPI(...)
m = re.search(r"app\s*=\s*FastAPI\([^\)]*\)\s*\n", s)
if not m:
    # fallback: add at end
    insert_at = len(s)
else:
    insert_at = m.end()

snippet = r'''

@app.get("/api/status")
def api_status():
    """
    Lightweight runtime truth endpoint (no auth).
    Used by UUI and scripts to avoid "echo" states.
    """
    port = os.environ.get("PORT", "")
    station_env = os.environ.get("STATION_ENV", "")
    edit_key_set = bool(os.environ.get("STATION_EDIT_KEY", ""))

    # best-effort: read simple signals if files exist
    root = os.environ.get("STATION_ROOT", "")
    return {
        "ok": True,
        "service": "station-backend",
        "time_utc": datetime.datetime.utcnow().isoformat() + "Z",
        "port_env": port,
        "station_env": station_env,
        "edit_key_set": edit_key_set,
        "root_env": root,
    }
'''
s2 = s[:insert_at] + snippet + s[insert_at:]
p.write_text(s2, encoding="utf-8")
print("OK: added /api/status")
PY

echo ">>> Done. Restart backend to load changes."
