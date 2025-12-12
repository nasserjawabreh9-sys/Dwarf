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
