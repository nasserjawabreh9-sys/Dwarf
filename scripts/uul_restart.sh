#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail
ROOT="${STATION_ROOT:-$HOME/station_root}"
bash "$ROOT/scripts/uul_stop.sh"
bash "$ROOT/scripts/uul_run.sh"
