from starlette.applications import Starlette
from starlette.responses import JSONResponse
from starlette.routing import Route
from app.routes import senses_plus
from app.routes import ops_exec
from app.routes import agent
from app.routes import dynamo
from app.routes import uui_config
from app.routes import hooks
from app.routes import senses

async def health(request):
    return JSONResponse({"ok": True, "service": "station-backend", "engine": "starlette"})

routes = [
    *senses_plus.routes,

    *ops_exec.routes,

    *agent.routes,

    *dynamo.routes,

    *hooks.routes,

    *senses.routes,

    *uui_config.routes,

    *uui_config.routes,

    # --- HOOKS ---
    *hooks.routes,

    # --- SENSES ---
    *senses.routes,

    Route("/health", health, methods=["GET"]),
]

app = Starlette(debug=False, routes=routes)
