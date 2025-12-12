#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
ROOT="$HOME/station_root"
cd "$ROOT"

echo ">>> [R9800] Termux-like Console (UI + safe backend exec) ..."

mkdir -p backend/app/routes backend/app/ops_logs
touch backend/app/routes/__init__.py

cat > backend/app/routes/ops_exec.py <<'PY'
import os, json, time, subprocess
from pathlib import Path
from starlette.responses import JSONResponse
from starlette.requests import Request
from starlette.routing import Route
from app.uui_store import expected_edit_key

ROOT = Path(__file__).resolve().parents[2]
LOG = ROOT / "backend" / "app" / "ops_logs" / "ops_exec.log.jsonl"
LOG.parent.mkdir(parents=True, exist_ok=True)

ALLOW = {
    "pwd": ["pwd"],
    "ls": ["ls", "-la"],
    "git_status": ["git", "status"],
    "git_log": ["git", "--no-pager", "log", "-n", "20", "--oneline"],
    "backend_health_curl": ["curl", "-sS", "http://127.0.0.1:8000/health"],
    "frontend_pkg": ["bash", "-lc", "cd frontend && npm -v && node -v"],
}

def now_iso():
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())

def _auth_ok(request: Request) -> bool:
    got = (request.headers.get("X-Edit-Key") or "").strip()
    return got != "" and got == expected_edit_key()

async def exec_cmd(request: Request):
    if not _auth_ok(request):
        return JSONResponse({"ok": False, "error": "forbidden"}, status_code=403)

    body={}
    try: body=await request.json()
    except Exception: body={}

    name = str(body.get("name") or "").strip()
    if name not in ALLOW:
        return JSONResponse({"ok": False, "error": "not_allowed", "allowed": sorted(ALLOW.keys())}, status_code=400)

    cmd = ALLOW[name]
    cwd = str(body.get("cwd") or str(ROOT)).strip()
    if not cwd:
        cwd = str(ROOT)

    entry = {"ts": now_iso(), "name": name, "cmd": cmd, "cwd": cwd}
    try:
        p = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, timeout=20)
        entry["rc"] = p.returncode
        entry["stdout"] = (p.stdout or "")[:8000]
        entry["stderr"] = (p.stderr or "")[:8000]
    except Exception as e:
        entry["rc"] = -1
        entry["stderr"] = str(e)

    with LOG.open("a", encoding="utf-8") as f:
        f.write(json.dumps(entry, ensure_ascii=False) + "\n")

    return JSONResponse({"ok": True, "entry": entry, "allowed": sorted(ALLOW.keys())})

async def allowed(request: Request):
    return JSONResponse({"ok": True, "allowed": sorted(ALLOW.keys()), "note": "Exec requires X-Edit-Key"})

routes = [
    Route("/api/ops/allowed", allowed, methods=["GET"]),
    Route("/api/ops/exec", exec_cmd, methods=["POST"]),
]
PY

# Patch main.py
python - <<'PY'
from pathlib import Path
import re
p = Path("backend/app/main.py")
txt = p.read_text(encoding="utf-8")

def ensure_import(line: str):
    global txt
    if line in txt: return
    txt = txt.replace("from starlette.routing import Route",
                      "from starlette.routing import Route\n"+line, 1)

ensure_import("from app.routes import ops_exec")

if "/api/ops/exec" not in txt:
    txt = re.sub(r"routes\s*=\s*\[", "routes = [\n    *ops_exec.routes,\n", txt, count=1)

p.write_text(txt, encoding="utf-8")
print("OK: main.py wired ops_exec.routes")
PY

# Frontend: patch Settings.tsx to add Console panel (simple)
python - <<'PY'
from pathlib import Path
import re
p = Path("frontend/src/pages/Settings.tsx")
txt = p.read_text(encoding="utf-8")

MARK="TERMUX_CONSOLE_PANEL__R9800"
if MARK not in txt:
    panel = r'''
      {/* TERMUX_CONSOLE_PANEL__R9800 */}
      <div className="mt-6 rounded-xl border p-4">
        <div className="text-lg font-semibold mb-2">Console (Termux-like)</div>
        <div className="text-sm opacity-80 mb-2">Calls backend: GET /api/ops/allowed, POST /api/ops/exec (Edit Key required)</div>

        <div className="flex flex-wrap gap-2">
          <button className="rounded bg-black text-white px-3 py-1"
            onClick={async () => {
              try{
                const j = await callApi("/api/ops/allowed", { method:"GET" });
                setStatus("OPS allowed: " + JSON.stringify(j));
              }catch(e:any){ setStatus("OPS allowed FAIL: " + (e?.message||"unknown")); }
            }}
          >Allowed</button>

          <button className="rounded bg-black text-white px-3 py-1"
            onClick={async () => {
              try{
                const j = await callApi("/api/ops/exec", {
                  method:"POST",
                  headers:{ "Content-Type":"application/json", "X-Edit-Key": keys.edit_mode_key || "" },
                  body: JSON.stringify({ name:"git_status" })
                });
                setStatus("OPS git_status: " + JSON.stringify(j.entry));
              }catch(e:any){ setStatus("OPS exec FAIL: " + (e?.message||"unknown")); }
            }}
          >git status</button>

          <button className="rounded bg-black text-white px-3 py-1"
            onClick={async () => {
              try{
                const j = await callApi("/api/ops/exec", {
                  method:"POST",
                  headers:{ "Content-Type":"application/json", "X-Edit-Key": keys.edit_mode_key || "" },
                  body: JSON.stringify({ name:"git_log" })
                });
                setStatus("OPS git_log: " + (j.entry.stdout || ""));
              }catch(e:any){ setStatus("OPS exec FAIL: " + (e?.message||"unknown")); }
            }}
          >git log</button>
        </div>
      </div>
'''
    # Put after Senses/Hooks panel marker if exists, else near end.
    if "SENSES_AND_HOOKS_PANEL__R9200" in txt:
        txt = txt.replace("SENSES_AND_HOOKS_PANEL__R9200 */", "SENSES_AND_HOOKS_PANEL__R9200 */"+panel)
    else:
        txt = re.sub(r"(</div>\s*</div>\s*\);\s*\}\s*export\s+default)", panel + r"\n\1", txt, count=1, flags=re.S)

    txt = txt.replace("{/* TERMUX_CONSOLE_PANEL__R9800 */", "{/* TERMUX_CONSOLE_PANEL__R9800 */}\n")  # normalize

p.write_text(txt, encoding="utf-8")
print("OK: Settings.tsx patched with Console panel")
PY

echo ">>> [R9800] DONE."
