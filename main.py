import os
import json
import requests
import subprocess

from starlette.applications import Starlette
from starlette.responses import JSONResponse, PlainTextResponse
from starlette.routing import Route
from starlette.middleware.cors import CORSMiddleware

async def health(request):
    return JSONResponse({"status": "ok", "engine": "dwarf-core", "runtime": "uul-termux"})

def local_brain(p: str) -> str:
    return f"[LOCAL·NasserLite] {p}"

def web_brain(p: str) -> str:
    try:
        r = requests.get(
            "https://api.duckduckgo.com/",
            params={"q": p, "format": "json"},
            timeout=3,
        )
        j = r.json()
        if j.get("AbstractText"):
            return j["AbstractText"]
    except Exception:
        pass
    return ""

def llm_brain(p: str) -> str:
    key = os.getenv("LLM_API_KEY", "").strip()
    if not key:
        return ""
    try:
        r = requests.post(
            "https://api.openai.com/v1/chat/completions",
            headers={
                "Authorization": f"Bearer {key}",
                "Content-Type": "application/json",
            },
            json={
                "model": "gpt-4o-mini",
                "messages": [
                    {
                        "role": "system",
                        "content": "You are Dwarf Sovereign Agent. Precise, intelligent, UUL-disciplined.",
                    },
                    {"role": "user", "content": p},
                ],
            },
            timeout=10,
        )
        data = r.json()
        return data["choices"][0]["message"]["content"]
    except Exception:
        return ""

async def chat(request):
    try:
        body = await request.json()
    except Exception:
        body = {}
    p = str(body.get("prompt", "")).strip()
    if not p:
        return JSONResponse({"mode": "empty", "response": "Empty."})

    w = web_brain(p)
    if w:
        return JSONResponse({"mode": "web", "response": w})

    l = llm_brain(p)
    if l:
        return JSONResponse({"mode": "llm", "response": l})

    return JSONResponse({"mode": "local", "response": local_brain(p)})

async def seed_github(request):
    tok = request.query_params.get("tok", "").strip()
    if not tok:
        return PlainTextResponse("GitHub token required.", status_code=400)

    cmds = [
        "git init",
        "git add .",
        'git commit -m "seed" || echo "no changes"',
        "git branch -M main",
        "git remote remove origin || true",
        f"git remote add origin https://{tok}@github.com/nasserjawabreh9-sys/Dwarf.git",
        "git push -u origin main --force",
    ]
    out_all = []
    for c in cmds:
        out_all.append(f"$ {c}")
        out_all.append(subprocess.getoutput(c))
    return PlainTextResponse("\n".join(out_all))

async def seed_render(request):
    t = request.query_params.get("t", "").strip()
    s = request.query_params.get("s", "").strip()
    if not t or not s:
        return PlainTextResponse("Render token + service id required.", status_code=400)

    cmd = (
        f'curl -s -X POST https://api.render.com/v1/services/{s}/deploys '
        f'-H "Authorization: Bearer {t}" '
        f'-H "Content-Type: application/json" '
        f'-d \'{{"clearCache": false}}\''
    )
    out = subprocess.getoutput(cmd)
    return PlainTextResponse(out or "Render deploy triggered.")

routes = [
    Route("/health", health),
    Route("/api/chat", chat, methods=["POST"]),
    Route("/seed/github", seed_github),
    Route("/seed/render", seed_render),
]

app = Starlette(routes=routes)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)
