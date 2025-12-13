#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail
ROOT="${STATION_ROOT:-$HOME/station_root}"
ARCH="${1:-}"
if [[ -z "$ARCH" || ! -f "$ARCH" ]]; then
  echo "usage: uul_restore.sh <backup.tgz>"
  exit 2
fi

mkdir -p "$ROOT/_restore_tmp"
tar -xzf "$ARCH" -C "$ROOT/_restore_tmp"
cp -R "$ROOT/_restore_tmp/"* "$ROOT/" 2>/dev/null || true
rm -rf "$ROOT/_restore_tmp"

echo "RESTORED from: $ARCH"
