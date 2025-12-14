#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="${STATION_ROOT:-$HOME/station_root}"
TARGET="$ROOT/backend/app/core/config.py"

if [ ! -f "$TARGET" ]; then
  echo "ERROR: missing $TARGET"
  exit 1
fi

echo ">>> Backup config.py"
cp -f "$TARGET" "$TARGET.bak_$(date +%Y%m%d_%H%M%S)"

echo ">>> Writing Termux-safe Pydantic v1 config.py"
cat > "$TARGET" <<'PY'
import os
from pydantic import BaseSettings

def _env_file():
    # Use .env if present (optional). Otherwise env vars only.
    # Try backend/.env then repo root/.env then none.
    here = os.path.dirname(__file__)
    backend_dir = os.path.abspath(os.path.join(here, "..", ".."))
    root_dir = os.path.abspath(os.path.join(backend_dir, ".."))
    for p in (os.path.join(backend_dir, ".env"), os.path.join(root_dir, ".env")):
        if os.path.isfile(p):
            return p
    return None

class Settings(BaseSettings):
    # ---- Core ----
    STATION_ENV: str = os.getenv("STATION_ENV", "prod")
    PORT: int = int(os.getenv("PORT", "8000") or "8000")
    STATION_ROOT: str = os.getenv("STATION_ROOT", "")

    # ---- Security / Ops ----
    STATION_EDIT_KEY: str = os.getenv("STATION_EDIT_KEY", "")

    # ---- Integrations (optional) ----
    STATION_OPENAI_API_KEY: str = os.getenv("STATION_OPENAI_API_KEY", os.getenv("OPENAI_API_KEY", ""))
    OPENAI_API_KEY: str = os.getenv("OPENAI_API_KEY", os.getenv("STATION_OPENAI_API_KEY", ""))
    GITHUB_TOKEN: str = os.getenv("GITHUB_TOKEN", "")
    RENDER_API_KEY: str = os.getenv("RENDER_API_KEY", "")

    class Config:
        env_file = _env_file()
        env_file_encoding = "utf-8"
        case_sensitive = False

settings = Settings()
PY

echo ">>> OK: patched $TARGET"
