#!/data/data/com.termux/files/usr/bin/bash
set -e
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"
export PYTHONIOENCODING="utf-8"

export STATION_ROOT="$HOME/station_root"

export STATION_BACKEND_HOST="127.0.0.1"
export STATION_BACKEND_PORT="8000"
export STATION_FRONTEND_PORT="5173"

# Optional defaults (do NOT put secrets here). Prefer UI -> LocalStorage -> backend store.
export STATION_EDIT_MODE_KEY="${STATION_EDIT_MODE_KEY:-1234}"

echo "[station_env] Loaded."
