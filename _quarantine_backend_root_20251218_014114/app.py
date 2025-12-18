from backend.app_fixed.main import app  # noqa
from .db_router import router as db_router
from backend.routes.db_health import router as db_health_router

app.include_router(db_router)

app.include_router(db_health_router)
