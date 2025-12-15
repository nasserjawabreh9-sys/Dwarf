#!/data/data/com.termux/files/usr/bin/bash
set -e

FILE=~/station_root/backend/asgi.py

echo "Patching $FILE"

sed -i 's|app.mount("/", inner_app)|app.mount("/legacy", inner_app)|' "$FILE"

echo "Done. New mount path: /legacy"
