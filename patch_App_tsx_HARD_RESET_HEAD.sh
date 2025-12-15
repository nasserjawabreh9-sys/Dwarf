#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

FILE="$HOME/station_root/frontend/src/App.tsx"
[ -f "$FILE" ] || { echo "ERROR: App.tsx not found"; exit 1; }

TS="$(date +%Y%m%d_%H%M%S)"
BK="$FILE.bak_hard_$TS"
cp "$FILE" "$BK"
echo "Backup created: $BK"

python - <<'PY'
from pathlib import Path
import re

p = Path.home() / "station_root/frontend/src/App.tsx"
s = p.read_text(encoding="utf-8", errors="ignore")

# 0) Cut anything BEFORE the first import/export (fix broken heads like "}, []);")
m = re.search(r'^(import\s|\s*export\s)', s, flags=re.M)
if m:
    s = s[m.start():]
else:
    # if no imports found, keep as-is; but this is unusual
    pass

# 1) Remove any leftover orphan closers at top (common after partial regex edits)
# remove repeated junk lines at the very beginning only
s = re.sub(r'^\s*(\},\s*\[\s*\]\s*\)\s*;\s*|\]\s*\)\s*;\s*|\}\s*\)\s*;\s*|;\s*)\s*\n+', '', s, flags=re.M)

# 2) Fix the "useEffect returns JSX" bug inside App: remove that JSX return block
# Specifically remove:
#   return (
#     <div ...> ... </div>
#   );
s = re.sub(
    r'(\n\s*)return\s*\(\s*\n\s*<div[\s\S]*?</div>\s*\n\s*\)\s*;?',
    r'\1',
    s,
    flags=re.M
)

# 3) Ensure there is a valid clock useEffect somewhere in App:
# If we find "const [now, setNow]" and then a broken useEffect block, replace the whole first useEffect after that.
if "const [now" in s and "setNow" in s:
    # replace first useEffect(...) block after setNow declaration
    pat = r'(const\s+\[now[^\n]*\n[\s\S]*?)(useEffect\s*\([\s\S]*?\);\s*)'
    repl = r'\1useEffect(() => {\n  const t = setInterval(() => setNow(Date.now()), 1000);\n  return () => clearInterval(t);\n}, []);\n'
    s2 = re.sub(pat, repl, s, count=1)
    s = s2

# 4) Final cleanup: collapse huge blank runs
s = re.sub(r'\n{4,}', '\n\n\n', s)

p.write_text(s.rstrip() + "\n", encoding="utf-8")
print("OK: App.tsx hard-fixed (head cleaned + useEffect corrected).")
PY

echo "==> Build frontend"
cd "$HOME/station_root/frontend"
npm run build
