#!/data/data/com.termux/files/usr/bin/bash
set -e
# Enforce single source for Edit Mode Key
export STATION_EDIT_KEY="${STATION_EDIT_KEY:-1234}"

# Write env snapshot
cat > station_meta/locks/hardening.env <<EOF
STATION_EDIT_KEY=${STATION_EDIT_KEY}
HARDENING_APPLIED=1
DATE=$(date -Is)
EOF

echo "Hardening applied. Edit key enforced."
