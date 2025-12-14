#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
ROOT="${STATION_ROOT:-$HOME/station_root}"
APP="$ROOT/frontend/src/App.tsx"

echo ">>> Context (lines 1..60)"
nl -ba "$APP" | sed -n '1,80p'

echo ">>> Backup"
cp -f "$APP" "$APP.bak.$(date +%s)"

python - <<'PY' "$APP"
import sys, re, pathlib
p = pathlib.Path(sys.argv[1])
s = p.read_text(encoding="utf-8", errors="ignore")

# 1) If there's a broken "return () => clearInterval(t);" outside useEffect, remove it.
# We'll re-inject a correct useEffect block.
s = re.sub(r"^\s*return\s*\(\s*\)\s*=>\s*clearInterval\(\s*([A-Za-z_][A-Za-z0-9_]*)\s*\)\s*;\s*$",
           r"", s, flags=re.M)

# 2) Try to locate an existing useEffect that sets an interval; if found, normalize it.
pattern = re.compile(
    r"useEffect\s*\(\s*\(\s*\)\s*=>\s*\{\s*([\s\S]*?)\}\s*,\s*\[\s*\]\s*\)\s*;?",
    re.M
)

def normalize(block: str) -> str:
    # if interval var exists
    m = re.search(r"const\s+([A-Za-z_][A-Za-z0-9_]*)\s*=\s*setInterval\s*\(", block)
    if not m:
        return None
    var = m.group(1)
    # remove any existing return cleanup in block
    block2 = re.sub(r"return\s*\(\s*\)\s*=>\s*clearInterval\(\s*"+re.escape(var)+r"\s*\)\s*;\s*", "", block)
    # ensure it ends cleanly
    block2 = block2.strip()
    return "useEffect(() => {\n  " + block2.replace("\n", "\n  ") + f"\n  return () => clearInterval({var});\n}}, []);\n"

replaced = False
def repl(m):
    global replaced
    norm = normalize(m.group(1))
    if norm:
        replaced = True
        return norm
    return m.group(0)

s2 = pattern.sub(repl, s, count=1)
s = s2

# 3) If we didn't find a suitable useEffect, inject a safe one near top of component.
if not replaced:
    # Find start of function component body (first "{")
    # Insert after first opening brace in App component.
    # Common patterns: function App() { ... } OR const App = () => { ... }
    inject = (
        "\n  // --- auto-fixed: stable interval cleanup ---\n"
        "  useEffect(() => {\n"
        "    const t = setInterval(() => {\n"
        "      // no-op tick (placeholder)\n"
        "    }, 1000);\n"
        "    return () => clearInterval(t);\n"
        "  }, []);\n"
    )
    # Ensure React hooks import exists
    if re.search(r"from\s+['\"]react['\"]", s):
        # Add useEffect to import if missing
        s = re.sub(r"(import\s*\{\s*)([^}]*)(\}\s*from\s*['\"]react['\"]\s*;?)",
                   lambda m: m.group(1) + (m.group(2).strip() + (", " if m.group(2).strip() else "") + ("useEffect" if "useEffect" not in m.group(2) else "")) + m.group(3),
                   s, count=1)
    elif re.search(r"import\s+React\s+from\s+['\"]react['\"]", s) and "useEffect" not in s:
        s = re.sub(r"import\s+React\s+from\s+['\"]react['\"]\s*;?",
                   "import React, { useEffect } from 'react';", s, count=1)
    else:
        # If no react import recognized, prepend a minimal one (rare)
        s = "import React, { useEffect } from 'react';\n" + s

    # inject into App component
    m = re.search(r"(function\s+App\s*\([^)]*\)\s*\{)", s)
    if m:
        s = s[:m.end()] + inject + s[m.end():]
    else:
        m = re.search(r"(const\s+App\s*=\s*\([^)]*\)\s*=>\s*\{)", s)
        if m:
            s = s[:m.end()] + inject + s[m.end():]
        else:
            # last resort: just append at end (won't help, but keeps file valid)
            s += "\n" + inject

p.write_text(s, encoding="utf-8")
print("OK: App.tsx normalized")
PY

echo ">>> Context after fix (lines 1..80)"
nl -ba "$APP" | sed -n '1,90p'
