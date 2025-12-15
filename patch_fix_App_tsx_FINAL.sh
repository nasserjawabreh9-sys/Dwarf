#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

FILE="$HOME/station_root/frontend/src/App.tsx"
[ -f "$FILE" ] || { echo "ERROR: App.tsx not found"; exit 1; }

TS="$(date +%Y%m%d_%H%M%S)"
BK="$FILE.bak_final_$TS"
cp "$FILE" "$BK"
echo "Backup created: $BK"

python - <<'PY'
from pathlib import Path
import re

p = Path.home() / "station_root/frontend/src/App.tsx"
s = p.read_text(encoding="utf-8", errors="ignore")

# 1) احذف أي useEffect قبل imports
s = re.sub(
    r'^\s*useEffect\s*\([\s\S]*?\);\s*',
    '',
    s,
    count=1
)

# 2) أصلح useEffect داخل App (منع JSX return)
s = re.sub(
    r'useEffect\s*\(\s*\(\s*\)\s*=>\s*\{\s*const\s+t\s*=\s*setInterval[\s\S]*?\}\s*,\s*\[\s*\]\s*\);',
    '''useEffect(() => {
  const t = setInterval(() => setNow(Date.now()), 1000);
  return () => clearInterval(t);
}, []);''',
    s
)

# تنظيف فراغات زائدة
s = re.sub(r'\n{3,}', '\n\n', s)

p.write_text(s.rstrip() + "\n", encoding="utf-8")
print("OK: App.tsx structure fixed correctly")
PY

echo "==> Build frontend"
cd "$HOME/station_root/frontend"
npm run build
