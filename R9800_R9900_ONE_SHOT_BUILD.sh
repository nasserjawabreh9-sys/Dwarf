#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="$HOME/station_root"
cd "$ROOT"

echo ">>> [R9800+R9900] Termux-like Console + OCR/STT stubs + wiring @ $ROOT"

mkdir -p backend/app/routes station_meta/logs

# -----------------------------
# (A) Console: guarded, room=ops, uses existing ops_run_cmd allowlist
# -----------------------------
cat > backend/app/routes/console.py <<'PY'
from starlette.responses import JSONResponse
from starlette.requests import Request
from starlette.routing import Route

from app.settings_store import expected_edit_key
from app.guards import require_room

# Console commands are aliases to ops_run_cmd allowlist keys
# This endpoint is a "Termux-like" console surface but stays safe by design.
ALIAS = {
  "pwd": "pwd",
  "ls": "ls",
  "git status": "git_status",
  "git log": "git_log",
}

def _auth_ok(request: Request) -> bool:
  got = (request.headers.get("X-Edit-Key") or "").strip()
  return got != "" and got == expected_edit_key()

@require_room("ops")
async def post_console(request: Request):
  if not _auth_ok(request):
    return JSONResponse({"ok": False, "error": "forbidden"}, status_code=403)

  body = {}
  try:
    body = await request.json()
  except Exception:
    body = {}

  line = (body.get("line") or "").strip()
  if not line:
    return JSONResponse({"ok": False, "error": "empty_line"}, status_code=400)

  # map to allowed ops cmd
  cmd = ALIAS.get(line)
  if not cmd:
    return JSONResponse({"ok": False, "error": "alias_not_allowed", "allowed": sorted(ALIAS.keys())}, status_code=400)

  # Import ops_run_cmd handler logic locally (no subprocess duplication)
  from app.routes.ops_run_cmd import ALLOWED
  import subprocess
  from pathlib import Path

  if cmd not in ALLOWED:
    return JSONResponse({"ok": False, "error": "cmd_not_allowed"}, status_code=400)

  try:
    p = subprocess.run(
      ALLOWED[cmd],
      capture_output=True,
      text=True,
      cwd=str(Path(__file__).resolve().parents[3])
    )
    return JSONResponse({
      "ok": True,
      "line": line,
      "cmd": cmd,
      "returncode": p.returncode,
      "stdout": (p.stdout or "")[-6000:],
      "stderr": (p.stderr or "")[-6000:]
    })
  except Exception as e:
    return JSONResponse({"ok": False, "error": str(e)}, status_code=500)

routes = [
  Route("/api/console", post_console, methods=["POST"]),
]
PY

# -----------------------------
# (B) OCR/STT stubs (Termux-safe): endpoints exist, return structured placeholders
# -----------------------------
cat > backend/app/routes/ocr_stt.py <<'PY'
import base64
from starlette.responses import JSONResponse
from starlette.requests import Request
from starlette.routing import Route

from app.settings_store import merged_keys
from app.guards import require_room

@require_room("core")
async def ocr_stub(request: Request):
  body = {}
  try:
    body = await request.json()
  except Exception:
    body = {}

  keys = merged_keys()
  ocr_key = (keys.get("ocr_key") or "").strip()

  # Accept either: {"image_b64": "..."} or {"text_hint":"..."}
  image_b64 = (body.get("image_b64") or "").strip()
  text_hint = (body.get("text_hint") or "").strip()

  meta = {"has_ocr_key": bool(ocr_key), "has_image_b64": bool(image_b64), "has_text_hint": bool(text_hint)}
  # We do not OCR locally here; this is a safe stub to wire later to provider.
  return JSONResponse({
    "ok": True,
    "mode": "stub",
    "meta": meta,
    "result": {
      "text": text_hint if text_hint else "",
      "confidence": 0.0,
      "provider": "stub"
    }
  })

@require_room("core")
async def stt_stub(request: Request):
  body = {}
  try:
    body = await request.json()
  except Exception:
    body = {}

  keys = merged_keys()
  tts_key = (keys.get("tts_key") or "").strip()  # reused slot; can be separate later

  # Accept: {"audio_b64":"..."} or {"text_hint":"..."}
  audio_b64 = (body.get("audio_b64") or "").strip()
  text_hint = (body.get("text_hint") or "").strip()

  meta = {"has_tts_key": bool(tts_key), "has_audio_b64": bool(audio_b64), "has_text_hint": bool(text_hint)}
  return JSONResponse({
    "ok": True,
    "mode": "stub",
    "meta": meta,
    "result": {
      "text": text_hint if text_hint else "",
      "confidence": 0.0,
      "provider": "stub"
    }
  })

routes = [
  Route("/api/ocr", ocr_stub, methods=["POST"]),
  Route("/api/stt", stt_stub, methods=["POST"]),
]
PY

# -----------------------------
# (C) Wire routes into backend/app/main.py (safe patch)
# -----------------------------
python - <<'PY'
from pathlib import Path
import re

p = Path("backend/app/main.py")
txt = p.read_text(encoding="utf-8")

def ensure_import(line: str):
  global txt
  if line in txt:
    return
  m = re.search(r"from\s+starlette\.routing\s+import\s+Route.*", txt)
  if m:
    txt = txt.replace(m.group(0), m.group(0) + "\n" + line, 1)
  else:
    txt = line + "\n" + txt

ensure_import("from app.routes import console")
ensure_import("from app.routes import ocr_stt")

if re.search(r"routes\s*=\s*\[", txt) is None:
  raise SystemExit("main.py has no routes=[...] list; cannot patch safely.")

def inject_once(signature: str, line: str):
  global txt
  if signature in txt:
    return
  txt = re.sub(r"routes\s*=\s*\[", "routes = [\n" + line, txt, count=1)

inject_once("/api/console", "    *console.routes,\n")
inject_once("/api/ocr", "    *ocr_stt.routes,\n")

p.write_text(txt, encoding="utf-8")
print("OK: main.py wired console + ocr_stt")
PY

# -----------------------------
# (D) Frontend: add a simple Console page if frontend/src exists (non-breaking)
# -----------------------------
if [ -d "frontend/src" ]; then
  echo ">>> [R9800] frontend detected: adding Console panel (non-breaking)"

  mkdir -p frontend/src/pages
  cat > frontend/src/pages/Console.jsx <<'JSX'
import React, { useMemo, useState } from "react";

export default function Console() {
  const [line, setLine] = useState("git status");
  const [out, setOut] = useState("");
  const [busy, setBusy] = useState(false);

  const editKey = useMemo(() => {
    try { return localStorage.getItem("edit_mode_key") || "1234"; } catch { return "1234"; }
  }, []);

  async function run() {
    setBusy(true);
    setOut("");
    try {
      const r = await fetch("/api/console", {
        method: "POST",
        headers: { "Content-Type": "application/json", "X-Edit-Key": editKey },
        body: JSON.stringify({ line }),
      });
      const j = await r.json();
      setOut(JSON.stringify(j, null, 2));
    } catch (e) {
      setOut(String(e));
    } finally {
      setBusy(false);
    }
  }

  return (
    <div style={{ padding: 16, maxWidth: 1000, margin: "0 auto" }}>
      <h2>Console</h2>
      <p style={{ opacity: 0.8 }}>
        Safe Termux-like console. Allowed: <code>pwd</code>, <code>ls</code>, <code>git status</code>, <code>git log</code>.
        Requires Edit Mode Key.
      </p>

      <div style={{ display: "flex", gap: 8 }}>
        <input
          value={line}
          onChange={(e) => setLine(e.target.value)}
          style={{ flex: 1, padding: 10, borderRadius: 10, border: "1px solid #333" }}
        />
        <button onClick={run} disabled={busy} style={{ padding: "10px 14px", borderRadius: 10 }}>
          {busy ? "Running..." : "Run"}
        </button>
      </div>

      <pre style={{ marginTop: 12, padding: 12, borderRadius: 12, background: "#0b0b0b", color: "#ddd", minHeight: 240, overflow: "auto" }}>
        {out}
      </pre>
    </div>
  );
}
JSX

  # Try to auto-wire into router if App.jsx exists; else just leave page file.
  if [ -f "frontend/src/App.jsx" ] && ! grep -q "Console" frontend/src/App.jsx; then
    python - <<'PY'
from pathlib import Path
p = Path("frontend/src/App.jsx")
t = p.read_text(encoding="utf-8")

# ultra-safe: only add route link if a simple nav exists
# If project uses different routing, we do not break it.
if "react-router-dom" in t and "Routes" in t and "Route" in t:
    if "pages/Console" not in t:
        t = t.replace("from react", "from react", 1)
        t = t.replace("\n", "\nimport Console from './pages/Console.jsx';\n", 1)
    if "path=\"/console\"" not in t:
        t = t.replace("</Routes>", "  <Route path=\"/console\" element={<Console/>} />\n</Routes>", 1)
p.write_text(t, encoding="utf-8")
print("OK: attempted to wire /console route (if router existed)")
PY
  else
    echo ">>> [R9800] App.jsx not patched (router not detected or already wired). Page is ready at frontend/src/pages/Console.jsx"
  fi
else
  echo ">>> [R9800] frontend/src not found; skipping UI patch (backend endpoints still ready)."
fi

# -----------------------------
# (E) Verify endpoints quickly (backend must be running)
# -----------------------------
echo ">>> [VERIFY] If backend is running, these should respond:"
echo "  curl -sS http://127.0.0.1:8000/health"
echo "  curl -sS http://127.0.0.1:8000/api/settings | head -c 200 && echo"
echo "  curl -sS -X POST http://127.0.0.1:8000/api/console -H 'Content-Type: application/json' -H 'X-Edit-Key: 1234' -d '{\"line\":\"git status\"}' | head -c 300 && echo"
echo "  curl -sS -X POST http://127.0.0.1:8000/api/ocr -H 'Content-Type: application/json' -d '{\"text_hint\":\"sample\"}' | head -c 260 && echo"
echo "  curl -sS -X POST http://127.0.0.1:8000/api/stt -H 'Content-Type: application/json' -d '{\"text_hint\":\"sample\"}' | head -c 260 && echo"

echo ">>> [R9800+R9900] DONE."
