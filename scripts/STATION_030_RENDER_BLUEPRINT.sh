#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="${STATION_ROOT:-$HOME/station_root}"
BACK="$ROOT/backend"
FRONT="$ROOT/frontend"

echo "=== [STATION_030] Create Render Blueprint (render.yaml) ==="
echo "ROOT=$ROOT"
echo

if [ ! -d "$BACK" ]; then
  echo "ERROR: backend dir not found: $BACK"
  exit 1
fi

if [ ! -d "$FRONT" ]; then
  echo "ERROR: frontend dir not found: $FRONT"
  exit 1
fi

# Ensure frontend supports VITE_BACKEND_URL (create .env.example)
cat > "$FRONT/.env.example" <<'EOF'
# Frontend env (Render Static Site will set this)
VITE_BACKEND_URL=https://your-backend.onrender.com
EOF

# Create render.yaml blueprint
cat > "$ROOT/render.yaml" <<'YAML'
services:
  - type: web
    name: station-backend
    env: python
    rootDir: backend
    plan: free
    buildCommand: pip install -r requirements.txt
    startCommand: backend/ops/run_render.sh
    envVars:
      - key: STATION_ENV
        value: prod
      - key: STATION_EDIT_KEY
        value: "1234"
      - key: OPENAI_API_KEY
        sync: false
      - key: STATION_OPENAI_API_KEY
        sync: false
      - key: GITHUB_TOKEN
        sync: false
      - key: RENDER_API_KEY
        sync: false

  - type: web
    name: station-frontend
    env: static
    rootDir: frontend
    buildCommand: npm ci && npm run build
    staticPublishPath: dist
    envVars:
      - key: VITE_BACKEND_URL
        sync: false
YAML

echo "Created: $ROOT/render.yaml"
echo "Created: $FRONT/.env.example"
echo

echo "OK: Render blueprint prepared."
echo "Next: Commit + Push to GitHub, then in Render use 'Blueprint' deploy from repo."
