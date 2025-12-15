#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

FILE="$HOME/station_root/frontend/src/App.tsx"
[ -f "$FILE" ] || { echo "ERROR: App.tsx not found"; exit 1; }

TS="$(date +%Y%m%d_%H%M%S)"
BK="$FILE.bak_cleanup_$TS"
cp "$FILE" "$BK"
echo "Backup created: $BK"

python - <<'PY'
from pathlib import Path
import re

p = Path.home() / "station_root/frontend/src/App.tsx"
s = p.read_text(encoding="utf-8", errors="ignore")

orig = s

# Remove ONLY the invalid cleanup line(s) that cause TS1005
# (these are safe to remove if they are outside useEffect)
s = re.sub(r'^\s*return\s*\(\s*\)\s*=>\s*clearInterval\s*\(\s*\w+\s*\)\s*;\s*$', '', s, flags=re.M)

# Also remove stray "return () => clearInterval(...)" with different var names/spaces
s = re.sub(r'^\s*return\s*\(\s*\)\s*=>\s*clearInterval\s*\(\s*[^)]+\s*\)\s*;\s*$', '', s, flags=re.M)

# Cleanup multiple blank lines
s = re.sub(r'\n{3,}', '\n\n', s)

if s == orig:
    print("WARN: No matching cleanup return line found; file unchanged.")
else:
    p.write_text(s.rstrip() + "\n", encoding="utf-8")
    print("OK: Removed invalid cleanup return line(s).")
PY

echo "==> Build"
cd "$HOME/station_root/frontend"
npm run build
