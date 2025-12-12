#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
ROOT="$HOME/station_root"
cd "$ROOT"

echo ">>> [R9700] Agent intelligence boost (offline rules + optional online LLM) ..."

mkdir -p backend/app/routes station_meta/agent
touch backend/app/routes/__init__.py

# Simple local memory/log
cat > backend/app/agent_memory.py <<'PY'
import json, os
from pathlib import Path
from typing import Any, Dict, List

ROOT = Path(__file__).resolve().parents[2]
LOG = ROOT / "station_meta" / "agent" / "decisions.log.jsonl"
LOG.parent.mkdir(parents=True, exist_ok=True)

def append(entry: Dict[str, Any]) -> None:
    with LOG.open("a", encoding="utf-8") as f:
        f.write(json.dumps(entry, ensure_ascii=False) + "\n")

def tail(n: int = 50) -> List[Dict[str, Any]]:
    if not LOG.exists():
        return []
    lines = LOG.read_text(encoding="utf-8").splitlines()
    out=[]
    for s in lines[-max(1, min(n, 200)):]:
        try: out.append(json.loads(s))
        except Exception: pass
    return out
PY

# Agent route: /api/agent/decide + /api/agent/log
cat > backend/app/routes/agent.py <<'PY'
import os, time, requests
from starlette.responses import JSONResponse
from starlette.requests import Request
from starlette.routing import Route
from app.uui_store import merged_keys, expected_edit_key
from app.agent_memory import append, tail

def now_iso():
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())

def _mode(keys: dict) -> str:
    k = (os.getenv("STATION_OPENAI_API_KEY") or os.getenv("OPENAI_API_KEY") or keys.get("openai_api_key") or "").strip()
    return "online" if k and not k.startswith("CHANGE_ME") else "offline"

def _auth_ok(request: Request) -> bool:
    got = (request.headers.get("X-Edit-Key") or "").strip()
    return got != "" and got == expected_edit_key()

def offline_rules(goal: str, ctx: dict) -> dict:
    g = (goal or "").lower()
    # minimal rules (extend later)
    if "push" in g or "github" in g:
        return {"decision": "ops_git_push", "steps": ["open Ops -> autopush", "verify status"], "risk": "low"}
    if "deploy" in g or "render" in g:
        return {"decision": "ops_render_deploy", "steps": ["prepare env", "deploy script"], "risk": "medium"}
    if "senses" in g or "ocr" in g or "stt" in g:
        return {"decision": "senses_pipeline", "steps": ["verify endpoints", "configure keys", "run tests"], "risk": "low"}
    return {"decision": "general_plan", "steps": ["clarify target", "run minimal task", "log outputs"], "risk": "low"}

def online_llm(goal: str, ctx: dict, api_key: str) -> dict:
    # Uses OpenAI Responses API via HTTPS (no SDK dependency).
    # If internet blocked, it will fall back to offline.
    url = "https://api.openai.com/v1/responses"
    headers = {"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"}
    prompt = {
        "role": "user",
        "content": f"Goal: {goal}\nContext(JSON): {ctx}\nReturn JSON with fields: decision, steps[], risk."
    }
    body = {"model": "gpt-5", "input": [prompt], "temperature": 0.2}
    r = requests.post(url, headers=headers, json=body, timeout=15)
    j = r.json()
    # try extract text
    txt = ""
    try:
        out = j.get("output") or []
        for item in out:
            for c in item.get("content") or []:
                if c.get("type") == "output_text":
                    txt += c.get("text","")
    except Exception:
        txt = ""
    return {"raw": j, "text": txt[:3000], "http": r.status_code}

async def decide(request: Request):
    keys = merged_keys()
    body={}
    try: body = await request.json()
    except Exception: body={}
    goal = str(body.get("goal") or "").strip()
    ctx  = body.get("context") or {}
    mode = _mode(keys)

    entry = {"ts": now_iso(), "mode": mode, "goal": goal, "context": ctx}

    if mode == "online":
        api_key = (os.getenv("STATION_OPENAI_API_KEY") or os.getenv("OPENAI_API_KEY") or keys.get("openai_api_key") or "").strip()
        try:
            llm = online_llm(goal, ctx, api_key)
            entry["llm"] = llm
            # if LLM produced JSON-like text, keep it; else keep offline result too
            off = offline_rules(goal, ctx)
            entry["offline"] = off
            append(entry)
            return JSONResponse({"ok": True, "mode": mode, "offline": off, "online": llm})
        except Exception as e:
            mode = "offline"
            entry["mode"] = mode
            entry["online_error"] = str(e)

    off = offline_rules(goal, ctx)
    entry["offline"] = off
    append(entry)
    return JSONResponse({"ok": True, "mode": "offline", "offline": off})

async def get_log(request: Request):
    n = 50
    try: n = int(request.query_params.get("n") or "50")
    except Exception: n = 50
    return JSONResponse({"ok": True, "items": tail(n)})

routes = [
    Route("/api/agent/decide", decide, methods=["POST"]),
    Route("/api/agent/log", get_log, methods=["GET"]),
]
PY

# Patch main.py to include agent.routes
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

ensure_import("from app.routes import agent")

if "/api/agent/decide" not in txt:
    txt = re.sub(r"routes\s*=\s*\[", "routes = [\n    *agent.routes,\n", txt, count=1)

p.write_text(txt, encoding="utf-8")
print("OK: main.py wired agent.routes")
PY

# Ensure requests already in requirements (usually yes)
REQ="backend/requirements.txt"
grep -q "^requests==" "$REQ" 2>/dev/null || echo "requests==2.31.0" >> "$REQ"

echo ">>> [R9700] DONE."
echo "Test (after restart):"
echo "  curl -sS -X POST http://127.0.0.1:8000/api/agent/decide -H 'Content-Type: application/json' -d '{\"goal\":\"push github\",\"context\":{}}'"
echo "  curl -sS http://127.0.0.1:8000/api/agent/log?n=5"
