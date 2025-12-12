#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="$HOME/station_root"
cd "$ROOT"

echo ">>> [R9600] Mask sensitive keys in GET /api/config/uui"

python - <<'PY'
from pathlib import Path
import re

p = Path("backend/app/routes/uui_config.py")
if not p.exists():
    raise SystemExit("ERR: backend/app/routes/uui_config.py not found")

txt = p.read_text(encoding="utf-8")

# Ensure we have get_config function
if "async def get_config" not in txt:
    raise SystemExit("ERR: get_config not found in uui_config.py")

MARK = "MASK_SENSITIVE_KEYS__R9600"
if MARK not in txt:
    helper = r'''
# MASK_SENSITIVE_KEYS__R9600
SENSITIVE_KEYS = {
  "openai_api_key",
  "github_token",
  "render_api_key",
  "whatsapp_key",
  "web_integration_key",
  "ocr_key",
  "tts_key",
  "email_smtp"
}

def _mask_value(v: str) -> str:
  s = ("" if v is None else str(v))
  if not s:
    return ""
  if len(s) <= 4:
    return "****"
  return "****" + s[-4:]

def masked_keys(keys: dict) -> dict:
  out = {}
  for k, v in (keys or {}).items():
    if k in SENSITIVE_KEYS:
      out[k] = _mask_value(v)
    else:
      out[k] = v
  return out
'''
    # Insert helper near imports (after imports block)
    # naive: insert after the last import line
    m = list(re.finditer(r"^\s*(from|import)\s+.*$", txt, flags=re.M))
    if not m:
        txt = helper + "\n" + txt
    else:
        last = m[-1]
        insert_pos = last.end()
        txt = txt[:insert_pos] + "\n" + helper + txt[insert_pos:]

# Patch get_config to return masked keys
# Replace: {"ok": True, "keys": merged_keys()}
txt2 = re.sub(
    r'return\s+JSONResponse\(\s*\{\s*"ok"\s*:\s*True\s*,\s*"keys"\s*:\s*merged_keys\(\)\s*\}\s*\)',
    'return JSONResponse({"ok": True, "keys": masked_keys(merged_keys())})',
    txt,
    count=1
)

if txt2 == txt:
    # if pattern didn't match, do a fallback surgical edit inside get_config body
    txt2 = re.sub(
        r'(async\s+def\s+get_config\s*\(.*?\)\s*:\s*\n)(\s*)return\s+JSONResponse\(\{.*?\}\)\s*\n',
        r'\1\2return JSONResponse({"ok": True, "keys": masked_keys(merged_keys())})\n',
        txt,
        count=1,
        flags=re.S
    )

p.write_text(txt2, encoding="utf-8")
print("OK: uui_config.py patched (GET now masks sensitive keys).")
PY

echo ">>> [R9600] Restart Station (hard best-effort)..."
pkill -f "uvicorn.*8000" >/dev/null 2>&1 || true
sleep 1
./station_full_run.sh >/dev/null 2>&1 || true
sleep 1

echo ">>> [R9600] Verify (GET /api/config/uui should be masked):"
curl -sS http://127.0.0.1:8000/api/config/uui | head -c 700 && echo
echo ">>> [R9600] DONE."
