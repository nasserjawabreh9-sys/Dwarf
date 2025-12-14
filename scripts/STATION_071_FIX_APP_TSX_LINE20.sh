#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
ROOT="${STATION_ROOT:-$HOME/station_root}"
APP="$ROOT/frontend/src/App.tsx"

echo ">>> Showing context around line 20"
nl -ba "$APP" | sed -n '1,80p' | sed -n '10,35p'

echo ">>> Applying safe patch to fix a common broken useEffect interval block (backup kept)"
cp -f "$APP" "$APP.bak.$(date +%s)"

python - <<'PY' "$APP"
import sys, re, pathlib
p = pathlib.Path(sys.argv[1])
s = p.read_text(encoding="utf-8", errors="ignore")

# If file already looks fine, don't force rewrite.
if "useEffect" in s and "clearInterval" in s:
    # Fix a very common broken fragment:
    # useEffect(() => { const t = setInterval(...); ) => clearInterval(t); }, [])
    s2 = re.sub(
        r"useEffect\s*\(\s*\(\s*\)\s*=>\s*\{\s*([\s\S]*?)\)\s*=>\s*clearInterval\(\s*([A-Za-z_][A-Za-z0-9_]*)\s*\)\s*;\s*\}\s*,\s*\[\s*\]\s*\)",
        lambda m: "useEffect(() => {\n" + m.group(1) + f"\n  return () => clearInterval({m.group(2)});\n}}, []);",
        s,
        flags=re.M
    )
    s = s2

# As fallback: ensure any "return () => clearInterval(t)" is properly inside useEffect block if present.
# (No aggressive rewrite; keep minimal)
p.write_text(s, encoding="utf-8")
print("OK: patch attempt written (see backup .bak.* if needed)")
PY

echo ">>> Re-check context"
nl -ba "$APP" | sed -n '10,35p'
