#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="${STATION_ROOT:-$HOME/station_root}"
BACK="$ROOT/backend"

echo "=== [RENDER_010] Patch: pin python + preflight + hardened run_render ==="
echo "ROOT=$ROOT"
echo "BACK=$BACK"
echo

if [ ! -d "$ROOT/.git" ]; then
  echo "ERROR: $ROOT is not a git repo. Run git init / clone first."
  exit 1
fi

if [ ! -d "$BACK" ]; then
  echo "ERROR: backend dir not found: $BACK"
  exit 1
fi

# 1) Pin python version for Render
cat > "$ROOT/.python-version" <<'TXT'
3.12.8
TXT

# 2) Env example (safe placeholders)
mkdir -p "$BACK"
cat > "$BACK/.env.example" <<'TXT'
STATION_ENV=prod
STATION_EDIT_KEY=1234

STATION_OPENAI_API_KEY=
OPENAI_API_KEY=

GITHUB_TOKEN=
RENDER_API_KEY=

TTS_KEY=
OCR_KEY=
WEBHOOKS_URL=
WHATSAPP_KEY=
EMAIL_SMTP=
GITHUB_REPO=OWNER/REPO
TXT

# 3) Preflight (warn only, no crash)
mkdir -p "$BACK/ops"
cat > "$BACK/ops/preflight.py" <<'PY'
import os, sys

SOFT_REQUIRED = ["STATION_EDIT_KEY"]
OPTIONAL_KEYS = [
  "STATION_OPENAI_API_KEY",
  "OPENAI_API_KEY",
  "GITHUB_TOKEN",
  "RENDER_API_KEY",
  "TTS_KEY",
  "OCR_KEY",
  "WEBHOOKS_URL",
  "WHATSAPP_KEY",
  "EMAIL_SMTP",
  "GITHUB_REPO",
]

def main():
  print(">>> [PREFLIGHT] Station Render Preflight")
  print("python =", sys.version.split()[0])

  missing_soft = [k for k in SOFT_REQUIRED if not os.getenv(k)]
  if missing_soft:
    print("!!! missing soft-required env:", ", ".join(missing_soft))
    print("    action: set them in Render Environment. Service can still run, but Ops may be limited.")
  else:
    print("OK soft-required env present")

  empty_optional = [k for k in OPTIONAL_KEYS if not os.getenv(k)]
  if empty_optional:
    print(".. optional keys empty (expected until you set them from UI):")
    for k in empty_optional:
      print(" -", k)

  port = os.getenv("PORT", "")
  if port:
    print("OK PORT =", port)
  else:
    print(".. PORT not set (local run)")

  print(">>> [PREFLIGHT] Done.")
  return 0

if __name__ == "__main__":
  raise SystemExit(main())
PY

# 4) Harden run_render.sh (preflight then uvicorn)
cat > "$BACK/ops/run_render.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail

: "${PORT:=8000}"
: "${STATION_ENV:=prod}"

cd "$(dirname "$0")/.."

echo ">>> [RUN_RENDER] STATION_ENV=$STATION_ENV PORT=$PORT"
python3 ops/preflight.py || true

exec python3 -m uvicorn app.main:app --host 0.0.0.0 --port "$PORT"
SH
chmod +x "$BACK/ops/run_render.sh"

echo "OK: patch applied."
echo "Files written:"
echo " - $ROOT/.python-version"
echo " - $BACK/.env.example"
echo " - $BACK/ops/preflight.py"
echo " - $BACK/ops/run_render.sh"
