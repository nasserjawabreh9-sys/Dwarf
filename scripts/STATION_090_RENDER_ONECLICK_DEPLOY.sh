#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="${STATION_ROOT:-$HOME/station_root}"
cd "$ROOT"

# ====== Requirements ======
: "${RENDER_API_KEY:?Set RENDER_API_KEY first: export RENDER_API_KEY='...'}"

# Auto-detect repo remote (must be set already)
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "ERROR: Not a git repo. Run inside station_root where .git exists."
  exit 1
fi

# ====== Inputs ======
SERVICE_NAME_HINT="${1:-dwarf}"            # e.g. dwarf or station
MSG="${2:-station: oneclick deploy}"       # commit message
BRANCH="${BRANCH:-main}"                   # default main

API="https://api.render.com/v1"
AUTH="Authorization: Bearer ${RENDER_API_KEY}"

echo "==[1/5] Git status =="
git status --porcelain || true

echo "==[2/5] Stage + Commit (best-effort) =="
git add -A
if git diff --cached --quiet; then
  echo "No changes to commit (OK)."
else
  git commit -m "$MSG"
fi

echo "==[3/5] Push to GitHub ($BRANCH) =="
git push origin "$BRANCH"

echo "==[4/5] Find Render service by name hint: '$SERVICE_NAME_HINT' =="
SERVICE_JSON="$(curl -fsS -H "$AUTH" "$API/services")"

SERVICE_ID="$(python - <<'PY' "$SERVICE_JSON" "$SERVICE_NAME_HINT"
import sys, json
data=json.loads(sys.argv[1])
hint=sys.argv[2].lower()
# try match by name contains hint
cands=[]
for s in data:
    name=(s.get("name") or "")
    if hint in name.lower():
        cands.append(s)
if not cands:
    # if none, show available names and fail
    names=[(x.get("name"), x.get("id")) for x in data]
    print("NO_MATCH")
    print(json.dumps(names, indent=2))
    sys.exit(2)
# pick the first match
print(cands[0].get("id",""))
PY
)"

if [[ "$SERVICE_ID" == "NO_MATCH" || -z "${SERVICE_ID}" ]]; then
  echo "ERROR: No Render service matched. Available services were printed above."
  exit 1
fi

echo "Matched serviceId: $SERVICE_ID"

echo "==[5/5] Trigger Deploy =="
DEPLOY_JSON="$(curl -fsS -X POST -H "$AUTH" -H "Content-Type: application/json" \
  "$API/services/$SERVICE_ID/deploys" -d '{}')"
echo "$DEPLOY_JSON" | python -m json.tool || true

# Try to extract service URL (best-effort)
SERVICE_DETAILS="$(curl -fsS -H "$AUTH" "$API/services/$SERVICE_ID")"
SERVICE_URL="$(python - <<'PY' "$SERVICE_DETAILS"
import sys, json
d=json.loads(sys.argv[1])
u=(d.get("serviceDetails") or {}).get("url") or ""
print(u)
PY
)"

if [[ -n "$SERVICE_URL" ]]; then
  echo "Service URL: $SERVICE_URL"
  echo "Health check (may take time if build running):"
  curl -fsS "$SERVICE_URL/healthz" && echo
else
  echo "NOTE: Could not detect service URL automatically. Use Render dashboard URL."
fi

echo "DONE."
