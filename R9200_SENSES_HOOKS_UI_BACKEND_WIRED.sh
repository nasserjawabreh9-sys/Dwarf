#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="$HOME/station_root"
cd "$ROOT"

echo ">>> [R9200] Wiring Senses + Hooks (backend + frontend) @ $ROOT"

# -----------------------------
# 0) Ensure dirs
# -----------------------------
mkdir -p backend/app/routes station_meta/bindings

touch backend/app/__init__.py backend/app/routes/__init__.py

# -----------------------------
# 1) Backend: config reader (single truth: station_meta/bindings/uui_config.json + env override)
# -----------------------------
cat > backend/app/config_uui.py <<'PY'
import os, json
from pathlib import Path

ROOT_DIR = Path(__file__).resolve().parents[2]
UUI_STORE = ROOT_DIR / "station_meta" / "bindings" / "uui_config.json"

DEFAULT_KEYS = {
    "openai_api_key": "",
    "github_token": "",
    "tts_key": "",
    "webhooks_url": "",
    "ocr_key": "",
    "web_integration_key": "",
    "whatsapp_key": "",
    "email_smtp": "",
    "github_repo": "",
    "render_api_key": "",
    "edit_mode_key": "1234"
}

def read_uui_keys() -> dict:
    keys = dict(DEFAULT_KEYS)
    try:
        if UUI_STORE.exists():
            cfg = json.loads(UUI_STORE.read_text(encoding="utf-8"))
            got = (cfg.get("keys") or {})
            if isinstance(got, dict):
                keys.update(got)
    except Exception:
        pass

    # env overrides (optional)
    keys["edit_mode_key"] = (os.getenv("STATION_EDIT_KEY") or keys.get("edit_mode_key") or "1234").strip() or "1234"
    keys["webhooks_url"]  = (os.getenv("WEBHOOKS_URL") or keys.get("webhooks_url") or "").strip()
    keys["email_smtp"]    = (os.getenv("EMAIL_SMTP") or keys.get("email_smtp") or "").strip()
    keys["whatsapp_key"]  = (os.getenv("WHATSAPP_KEY") or keys.get("whatsapp_key") or "").strip()
    return keys

def expected_edit_key() -> str:
    k = (os.getenv("STATION_EDIT_KEY") or "").strip()
    if k:
        return k
    keys = read_uui_keys()
    return (keys.get("edit_mode_key") or "1234").strip() or "1234"
PY

# Ensure uui_config exists (do not clobber if already present)
if [ ! -f station_meta/bindings/uui_config.json ]; then
  cat > station_meta/bindings/uui_config.json <<'JSON'
{
  "keys": {
    "openai_api_key": "",
    "github_token": "",
    "tts_key": "",
    "webhooks_url": "",
    "ocr_key": "",
    "web_integration_key": "",
    "whatsapp_key": "",
    "email_smtp": "",
    "github_repo": "",
    "render_api_key": "",
    "edit_mode_key": "1234"
  }
}
JSON
fi

# -----------------------------
# 2) Backend: senses routes
# -----------------------------
cat > backend/app/routes/senses.py <<'PY'
from starlette.responses import JSONResponse
from starlette.requests import Request
from starlette.routing import Route
from starlette.datastructures import UploadFile

async def sense_text(request: Request):
    data = {}
    try:
        data = await request.json()
    except Exception:
        data = {}
    return JSONResponse({"ok": True, "sense": "text", "input": data})

async def sense_audio(request: Request):
    form = await request.form()
    f: UploadFile | None = form.get("audio")  # type: ignore
    b = await f.read() if f else b""
    return JSONResponse({"ok": True, "sense": "audio", "bytes": len(b)})

async def sense_image(request: Request):
    form = await request.form()
    f: UploadFile | None = form.get("image")  # type: ignore
    b = await f.read() if f else b""
    return JSONResponse({"ok": True, "sense": "image", "bytes": len(b)})

async def sense_video(request: Request):
    form = await request.form()
    f: UploadFile | None = form.get("video")  # type: ignore
    b = await f.read() if f else b""
    return JSONResponse({"ok": True, "sense": "video", "bytes": len(b)})

routes = [
    Route("/api/senses/text", sense_text, methods=["POST"]),
    Route("/api/senses/audio", sense_audio, methods=["POST"]),
    Route("/api/senses/image", sense_image, methods=["POST"]),
    Route("/api/senses/video", sense_video, methods=["POST"]),
]
PY

# -----------------------------
# 3) Backend: hooks routes (email/whatsapp/webhook)
# -----------------------------
cat > backend/app/routes/hooks.py <<'PY'
import requests
from starlette.responses import JSONResponse
from starlette.requests import Request
from starlette.routing import Route
from app.config_uui import expected_edit_key, read_uui_keys

def _auth_ok(request: Request) -> bool:
    got = (request.headers.get("X-Edit-Key") or "").strip()
    return got != "" and got == expected_edit_key()

async def hook_email(request: Request):
    if not _auth_ok(request):
        return JSONResponse({"ok": False, "error": "forbidden"}, status_code=403)
    payload = {}
    try:
        payload = await request.json()
    except Exception:
        payload = {}
    # Stub: just acknowledge. Real SMTP integration later using keys["email_smtp"].
    keys = read_uui_keys()
    return JSONResponse({"ok": True, "hook": "email", "smtp": bool(keys.get("email_smtp")), "payload": payload})

async def hook_whatsapp(request: Request):
    if not _auth_ok(request):
        return JSONResponse({"ok": False, "error": "forbidden"}, status_code=403)
    payload = {}
    try:
        payload = await request.json()
    except Exception:
        payload = {}
    # Stub: acknowledge. Real WA integration later using keys["whatsapp_key"].
    keys = read_uui_keys()
    return JSONResponse({"ok": True, "hook": "whatsapp", "key": bool(keys.get("whatsapp_key")), "payload": payload})

async def hook_webhook(request: Request):
    if not _auth_ok(request):
        return JSONResponse({"ok": False, "error": "forbidden"}, status_code=403)
    payload = {}
    try:
        payload = await request.json()
    except Exception:
        payload = {}
    keys = read_uui_keys()
    url = (keys.get("webhooks_url") or "").strip()
    if not url:
        return JSONResponse({"ok": False, "hook": "webhook", "error": "webhooks_url_missing", "payload": payload}, status_code=400)
    try:
        r = requests.post(url, json=payload, timeout=8)
        return JSONResponse({"ok": True, "hook": "webhook", "status_code": r.status_code})
    except Exception as e:
        return JSONResponse({"ok": False, "hook": "webhook", "error": str(e)}, status_code=500)

routes = [
    Route("/api/hooks/email", hook_email, methods=["POST"]),
    Route("/api/hooks/whatsapp", hook_whatsapp, methods=["POST"]),
    Route("/api/hooks/webhook", hook_webhook, methods=["POST"]),
]
PY

# -----------------------------
# 4) Backend requirements: multipart + requests (Termux-safe)
# -----------------------------
REQ="backend/requirements.txt"
grep -q "^python-multipart==" "$REQ" 2>/dev/null || echo "python-multipart==0.0.9" >> "$REQ"
grep -q "^requests==" "$REQ" 2>/dev/null || echo "requests==2.31.0" >> "$REQ"

# -----------------------------
# 5) Patch backend/app/main.py to mount routes (senses + hooks) safely
# -----------------------------
python - <<'PY'
from pathlib import Path
import re

p = Path("backend/app/main.py")
txt = p.read_text(encoding="utf-8")

# Ensure imports exist
if "from starlette.routing import Route" not in txt:
    raise SystemExit("backend/app/main.py unexpected: missing 'from starlette.routing import Route'")

if "from app.routes import senses" not in txt:
    txt = txt.replace("from starlette.routing import Route",
                      "from starlette.routing import Route\nfrom app.routes import senses")
if "from app.routes import hooks" not in txt:
    txt = txt.replace("from starlette.routing import Route",
                      "from starlette.routing import Route\nfrom app.routes import hooks")

# Ensure routes list exists
if re.search(r"routes\s*=\s*\[", txt) is None:
    raise SystemExit("backend/app/main.py unexpected: missing routes=[ ... ]")

# Insert senses+hooks into routes list only if not present
def inject_routes(label: str, insert_block: str):
    global txt
    if label in txt:
        return
    txt = re.sub(r"routes\s*=\s*\[", "routes = [\n" + insert_block, txt, count=1)

inject_routes("/api/senses/text", "    # --- SENSES ---\n" + "\n".join([
    "    *senses.routes,",
]) + "\n")

inject_routes("/api/hooks/email", "    # --- HOOKS ---\n" + "\n".join([
    "    *hooks.routes,",
]) + "\n")

p.write_text(txt, encoding="utf-8")
print("OK: backend/app/main.py wired senses+hooks routes.")
PY

# -----------------------------
# 6) Frontend: ensure Vite proxy to backend (so /api works)
# -----------------------------
if [ -f frontend/vite.config.ts ]; then
  python - <<'PY'
from pathlib import Path
import re

p = Path("frontend/vite.config.ts")
txt = p.read_text(encoding="utf-8")

# If proxy already exists, skip.
if "proxy:" in txt and "/api" in txt:
    print("OK: vite.config.ts proxy already present.")
else:
    # naive inject into defineConfig({ ... })
    # ensure server:{} exists
    if "server:" not in txt:
        txt = re.sub(r"defineConfig\(\{\s*", "defineConfig({\n  server: {\n    proxy: {\n      '/api': {\n        target: 'http://127.0.0.1:8000',\n        changeOrigin: true\n      }\n    }\n  },\n", txt, count=1)
    else:
        # insert proxy block into existing server
        txt = re.sub(r"server:\s*\{", "server: {\n    proxy: {\n      '/api': {\n        target: 'http://127.0.0.1:8000',\n        changeOrigin: true\n      }\n    },", txt, count=1)

    p.write_text(txt, encoding="utf-8")
    print("OK: vite.config.ts proxy added for /api -> 127.0.0.1:8000")
PY
else
  echo "WARN: frontend/vite.config.ts not found; skipped proxy patch."
fi

# -----------------------------
# 7) Frontend: patch Settings UI to show Senses + Hooks panels wired to backend
# -----------------------------
python - <<'PY'
from pathlib import Path
import re

p = Path("frontend/src/pages/Settings.tsx")
txt = p.read_text(encoding="utf-8")

# Guard: ensure page exists
if "function Settings" not in txt and "export default function" not in txt:
    raise SystemExit("Settings.tsx unexpected; cannot patch safely.")

# Add helper callApi if missing
if "async function callApi(" not in txt:
    inject = r'''
  async function callApi(path: string, opts: RequestInit) {
    const res = await fetch(path, opts);
    const j = await res.json().catch(() => ({}));
    if (!res.ok) throw new Error(j?.error || String(res.status));
    return j;
  }
'''
    # insert after React hooks / before fields memo
    m = re.search(r"\n\s*const\s+fields\s*=\s*useMemo", txt)
    if m:
        txt = txt[:m.start()] + inject + "\n" + txt[m.start():]
    else:
        # fallback insert near top of component
        txt = re.sub(r"(\{\s*$)", r"\1\n"+inject+"\n", txt, count=1, flags=re.M)

# Add UI block if missing marker
MARK = "SENSES_AND_HOOKS_PANEL__R9200"
if MARK not in txt:
    panel = r'''
      {/* SENSES_AND_HOOKS_PANEL__R9200 */}
      <div className="mt-6 grid gap-4 md:grid-cols-2">
        <div className="rounded-xl border p-4">
          <div className="text-lg font-semibold mb-2">Senses (Backend)</div>

          <div className="text-sm opacity-80 mb-2">POST /api/senses/text</div>
          <div className="flex gap-2">
            <input className="w-full rounded border px-2 py-1"
              placeholder='{"text":"hello"}'
              value={(window as any).__sense_text_payload || `{"text":"hello"}`}
              onChange={(e) => ((window as any).__sense_text_payload = e.target.value)}
            />
            <button className="rounded bg-black text-white px-3 py-1"
              onClick={async () => {
                try{
                  const payload = JSON.parse((window as any).__sense_text_payload || `{"text":"hello"}`);
                  const j = await callApi("/api/senses/text", {
                    method:"POST",
                    headers:{ "Content-Type":"application/json" },
                    body: JSON.stringify(payload)
                  });
                  setStatus("SENSE text OK: " + JSON.stringify(j));
                }catch(e:any){ setStatus("SENSE text FAIL: " + (e?.message||"unknown")); }
              }}
            >Send</button>
          </div>

          <div className="mt-4 text-sm opacity-80 mb-2">POST /api/senses/audio (multipart field: audio)</div>
          <input id="senseAudio" type="file" accept="audio/*" className="block w-full text-sm"/>
          <button className="mt-2 rounded bg-black text-white px-3 py-1"
            onClick={async () => {
              try{
                const el = document.getElementById("senseAudio") as HTMLInputElement;
                const f = el?.files?.[0];
                const fd = new FormData();
                if (f) fd.append("audio", f);
                const res = await fetch("/api/senses/audio", { method:"POST", body: fd });
                const j = await res.json().catch(()=>({}));
                if(!res.ok) throw new Error(j?.error || String(res.status));
                setStatus("SENSE audio OK: " + JSON.stringify(j));
              }catch(e:any){ setStatus("SENSE audio FAIL: " + (e?.message||"unknown")); }
            }}
          >Upload Audio</button>

          <div className="mt-4 text-sm opacity-80 mb-2">POST /api/senses/image (multipart field: image)</div>
          <input id="senseImage" type="file" accept="image/*" className="block w-full text-sm"/>
          <button className="mt-2 rounded bg-black text-white px-3 py-1"
            onClick={async () => {
              try{
                const el = document.getElementById("senseImage") as HTMLInputElement;
                const f = el?.files?.[0];
                const fd = new FormData();
                if (f) fd.append("image", f);
                const res = await fetch("/api/senses/image", { method:"POST", body: fd });
                const j = await res.json().catch(()=>({}));
                if(!res.ok) throw new Error(j?.error || String(res.status));
                setStatus("SENSE image OK: " + JSON.stringify(j));
              }catch(e:any){ setStatus("SENSE image FAIL: " + (e?.message||"unknown")); }
            }}
          >Upload Image</button>

          <div className="mt-4 text-sm opacity-80 mb-2">POST /api/senses/video (multipart field: video)</div>
          <input id="senseVideo" type="file" accept="video/*" className="block w-full text-sm"/>
          <button className="mt-2 rounded bg-black text-white px-3 py-1"
            onClick={async () => {
              try{
                const el = document.getElementById("senseVideo") as HTMLInputElement;
                const f = el?.files?.[0];
                const fd = new FormData();
                if (f) fd.append("video", f);
                const res = await fetch("/api/senses/video", { method:"POST", body: fd });
                const j = await res.json().catch(()=>({}));
                if(!res.ok) throw new Error(j?.error || String(res.status));
                setStatus("SENSE video OK: " + JSON.stringify(j));
              }catch(e:any){ setStatus("SENSE video FAIL: " + (e?.message||"unknown")); }
            }}
          >Upload Video</button>
        </div>

        <div className="rounded-xl border p-4">
          <div className="text-lg font-semibold mb-2">Hooks (Protected by Edit Key)</div>
          <div className="text-sm opacity-80 mb-2">Headers: X-Edit-Key = Edit Mode Key</div>

          <div className="text-sm opacity-80 mb-2">POST /api/hooks/email</div>
          <button className="rounded bg-black text-white px-3 py-1"
            onClick={async () => {
              try{
                const payload = { to:"test@example.com", subject:"Station Hook Test", body:"Hello from Station" };
                const j = await callApi("/api/hooks/email", {
                  method:"POST",
                  headers:{ "Content-Type":"application/json", "X-Edit-Key": keys.edit_mode_key || "" },
                  body: JSON.stringify(payload)
                });
                setStatus("HOOK email OK: " + JSON.stringify(j));
              }catch(e:any){ setStatus("HOOK email FAIL: " + (e?.message||"unknown")); }
            }}
          >Test Email Hook</button>

          <div className="mt-4 text-sm opacity-80 mb-2">POST /api/hooks/whatsapp</div>
          <button className="rounded bg-black text-white px-3 py-1"
            onClick={async () => {
              try{
                const payload = { to:"+0000000000", message:"Hello from Station WhatsApp Hook" };
                const j = await callApi("/api/hooks/whatsapp", {
                  method:"POST",
                  headers:{ "Content-Type":"application/json", "X-Edit-Key": keys.edit_mode_key || "" },
                  body: JSON.stringify(payload)
                });
                setStatus("HOOK whatsapp OK: " + JSON.stringify(j));
              }catch(e:any){ setStatus("HOOK whatsapp FAIL: " + (e?.message||"unknown")); }
            }}
          >Test WhatsApp Hook</button>

          <div className="mt-4 text-sm opacity-80 mb-2">POST /api/hooks/webhook (uses keys.webhooks_url)</div>
          <button className="rounded bg-black text-white px-3 py-1"
            onClick={async () => {
              try{
                const payload = { event:"station_webhook_test", ts: new Date().toISOString() };
                const j = await callApi("/api/hooks/webhook", {
                  method:"POST",
                  headers:{ "Content-Type":"application/json", "X-Edit-Key": keys.edit_mode_key || "" },
                  body: JSON.stringify(payload)
                });
                setStatus("HOOK webhook OK: " + JSON.stringify(j));
              }catch(e:any){ setStatus("HOOK webhook FAIL: " + (e?.message||"unknown")); }
            }}
          >Fire Webhook</button>

          <div className="mt-4 text-xs opacity-70">
            Notes: Email/WhatsApp hooks are stubs الآن (ack فقط). Webhook فعلي ويرسل لـ keys.webhooks_url.
          </div>
        </div>
      </div>
'''
    # place before the closing of main container: inject near status area
    # find "Output will appear here" or status block; else append before last return close
    if "Output will appear here" in txt:
        txt = txt.replace("Output will appear here.", "Output will appear here." + panel)
    else:
        # append near end of JSX return before last </div> of root if possible
        txt = re.sub(r"(</div>\s*</div>\s*\);\s*\}\s*export\s+default)", panel + r"\n\1", txt, count=1, flags=re.S)

p.write_text(txt, encoding="utf-8")
print("OK: Settings.tsx patched with Senses+Hooks panel.")
PY

# -----------------------------
# 8) Write a verification script (paths truth)
# -----------------------------
cat > scripts/ops/verify_senses_hooks_paths.sh <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

echo "=== BACKEND URL ==="
echo "http://127.0.0.1:8000"

echo
echo "=== HEALTH ==="
curl -sS http://127.0.0.1:8000/health && echo

echo
echo "=== SENSE TEXT (POST /api/senses/text) ==="
curl -sS -X POST http://127.0.0.1:8000/api/senses/text \
  -H "Content-Type: application/json" \
  -d '{"text":"hello"}' && echo

echo
echo "=== HOOK EMAIL (POST /api/hooks/email) - requires X-Edit-Key ==="
KEY="$(python - <<'PY'
import json, os
p=os.path.expanduser("~/station_root/station_meta/bindings/uui_config.json")
k="1234"
try:
  j=json.load(open(p,"r",encoding="utf-8"))
  k=((j.get("keys") or {}).get("edit_mode_key") or "1234").strip() or "1234"
except Exception:
  pass
print(k)
PY
)"
curl -sS -X POST http://127.0.0.1:8000/api/hooks/email \
  -H "Content-Type: application/json" \
  -H "X-Edit-Key: $KEY" \
  -d '{"to":"x@y.com","subject":"t","body":"b"}' && echo
EOF
chmod +x scripts/ops/verify_senses_hooks_paths.sh

echo ">>> [R9200] DONE."
echo "Next:"
echo "  1) Backend deps:  cd $ROOT/backend && source .venv/bin/activate && python -m pip install -r requirements.txt"
echo "  2) Restart:       cd $ROOT && ./station_full_run.sh"
echo "  3) Verify paths:  bash scripts/ops/verify_senses_hooks_paths.sh"
echo "  4) UI:            open frontend Settings -> Senses & Hooks (calls /api/*)"
