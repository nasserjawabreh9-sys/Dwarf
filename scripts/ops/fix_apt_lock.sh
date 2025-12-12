#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

LOCK1="/data/data/com.termux/files/usr/var/lib/dpkg/lock-frontend"
LOCK2="/data/data/com.termux/files/usr/var/lib/dpkg/lock"
LOCK3="/data/data/com.termux/files/usr/var/lib/apt/lists/lock"

echo ">>> [FIX] Checking running apt/dpkg..."
pgrep -a apt  || true
pgrep -a dpkg || true

# Try to find a blocking apt PID holding lock-frontend (best effort)
PID="$(ps -eo pid,cmd | awk '/apt/{print $1; exit}' || true)"

if [ -n "${PID:-}" ]; then
  echo ">>> [FIX] Sending TERM to apt pid=$PID"
  kill -TERM "$PID" 2>/dev/null || true
  sleep 2
  if kill -0 "$PID" 2>/dev/null; then
    echo ">>> [FIX] Sending KILL to apt pid=$PID"
    kill -KILL "$PID" 2>/dev/null || true
    sleep 1
  fi
fi

echo ">>> [FIX] Re-check apt/dpkg..."
pgrep -a apt  || true
pgrep -a dpkg || true

# If nothing is running, remove locks
if ! pgrep -x apt >/dev/null 2>&1 && ! pgrep -x dpkg >/dev/null 2>&1; then
  echo ">>> [FIX] Removing lock files..."
  rm -f "$LOCK1" "$LOCK2" "$LOCK3" || true
fi

echo ">>> [FIX] dpkg reconfigure..."
dpkg --configure -a || true

echo ">>> [FIX] apt repair..."
apt -f install -y || true

echo ">>> [FIX] apt update..."
apt update -y || apt update

echo ">>> [FIX] Done."
