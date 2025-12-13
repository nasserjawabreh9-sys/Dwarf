#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail
ROOT="${STATION_ROOT:-$HOME/station_root}"
mkdir -p "$ROOT/ops/hardening"

cat > "$ROOT/ops/hardening/HARDENING.md" <<'MD'
# Hardening (Local / Termux)

## Baseline
- Bind backend to 127.0.0.1 (default).
- Keep secrets out of repo and env files.
- Use UI/LocalStorage + backend settings store.

## Runtime
- Logs: station_logs/
- Backups: backups/
- Artifacts: artifacts/

## If exposing externally
- Put behind reverse proxy + TLS + auth.
- Add allowlist CORS.
- Add stronger rate limit + auth tokens.
MD

echo "Wrote: $ROOT/ops/hardening/HARDENING.md"
