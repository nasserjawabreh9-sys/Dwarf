#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

FILE="$HOME/station_root/frontend/src/App.tsx"

[ -f "$FILE" ] || { echo "ERROR: App.tsx not found"; exit 1; }

TS=$(date +%Y%m%d_%H%M%S)
BACKUP="$FILE.bak_$TS"
cp "$FILE" "$BACKUP"

echo "Backup created: $BACKUP"

python - <<'PY'
from pathlib import Path

p = Path.home() / "station_root/frontend/src/App.tsx"
lines = p.read_text(encoding="utf-8", errors="ignore").splitlines()

clean = []
for line in lines:
    # Stop immediately if bash/shebang/script pollution starts
    if line.startswith("#!") or line.strip().startswith("set -e") or line.strip().startswith("echo ") or line.strip().startswith("python "):
        break
    clean.append(line)

p.write_text("\n".join(clean).rstrip() + "\n", encoding="utf-8")
print("OK: App.tsx cleaned from script pollution")
PY

echo "DONE."
