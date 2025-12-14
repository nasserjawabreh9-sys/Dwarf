#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="${STATION_ROOT:-$HOME/station_root}"
FRONT="$ROOT/frontend"
BACK="$ROOT/backend"
APPMAIN="$BACK/app/main.py"
UIDIR="$BACK/app/static_ui"

echo ">>> Build frontend"
cd "$FRONT"
if [ -f package-lock.json ]; then
  npm ci
else
  npm install
fi
npm run build

echo ">>> Copy dist -> backend/app/static_ui"
rm -rf "$UIDIR"
mkdir -p "$UIDIR"
cp -r "$FRONT/dist/." "$UIDIR/"

echo ">>> Patch backend to serve /ui/"
python - <<'PY' "$APPMAIN"
import sys, pathlib, re

p = pathlib.Path(sys.argv[1])
s = p.read_text(encoding="utf-8", errors="ignore")

# Ensure imports
need = [
  "from fastapi.staticfiles import StaticFiles",
  "from starlette.responses import RedirectResponse",
]
for line in need:
  if line not in s:
    # put after existing fastapi imports if possible
    if "from fastapi import" in s:
      s = re.sub(r"(from fastapi import[^\n]*\n)", r"\1"+line+"\n", s, count=1)
    else:
      s = line+"\n"+s

# Mount StaticFiles once
if 'app.mount("/ui"' not in s:
  mount_snip = r'''
# ---- UI (static) ----
try:
    app.mount("/ui", StaticFiles(directory="app/static_ui", html=True), name="ui")
except Exception:
    # allow backend to run even if UI folder missing
    pass

@app.get("/ui/")
def ui_index():
    return RedirectResponse(url="/ui/index.html")
'''
  # insert after app = FastAPI(...)
  m = re.search(r"app\s*=\s*FastAPI\([^\)]*\)\s*\n", s)
  if m:
    s = s[:m.end()] + mount_snip + s[m.end():]
  else:
    s += "\n" + mount_snip + "\n"

p.write_text(s, encoding="utf-8")
print("OK: UI mounted at /ui")
PY

echo ">>> Done. Restart backend to load UI."
echo "UI URL will be: http://127.0.0.1:8010/ui/"
