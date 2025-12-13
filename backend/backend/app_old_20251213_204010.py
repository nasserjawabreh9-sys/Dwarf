from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from app.core.config import settings
from app.observability.mw import RequestIdMiddleware
from app.security.guards import body_size_guard, rate_limit_guard
from app.routers import health, settings as settings_router, rooms, dynamo, ops

app = FastAPI(title="Station", version="2.0.0-global")

app.add_middleware(RequestIdMiddleware)

app.add_middleware(
    CORSMiddleware,
    allow_origins=[o.strip() for o in settings.cors_allow_origins.split(",")] if settings.cors_allow_origins else ["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.middleware("http")
async def guards_middleware(request: Request, call_next):
    # Minimal hardening in dev-friendly way
    body_size_guard(request)
    rate_limit_guard(request)
    return await call_next(request)

app.include_router(health.router)
app.include_router(settings_router.router)
app.include_router(rooms.router)
app.include_router(dynamo.router)
app.include_router(ops.router)

