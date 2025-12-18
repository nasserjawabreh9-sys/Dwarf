#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
ROOT="$HOME/station_root"
BACK="$ROOT/backend"
VENV="$BACK/.venv"
LOGS="$ROOT/logs"
mkdir -p "$LOGS"

cd "$BACK"

if [ ! -d "$VENV" ]; then
  python -m venv "$VENV"
fi

source "$VENV/bin/activate"
python -m pip install --upgrade pip
pip install -r requirements.txt

# Run on 8000
uvicorn asgi:app --host 0.0.0.0 --port 8000 2>&1 | tee "$LOGS/backend.log"
