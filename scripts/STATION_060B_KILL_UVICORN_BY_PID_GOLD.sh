#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ports="${1:-8000 8010}"

echo ">>> Killing uvicorn by PID for ports: $ports"
echo

# Print candidates
echo ">>> Current uvicorn candidates:"
ps -ef | grep -E "uvicorn|python.*-m uvicorn|app\.main:app" | grep -v grep || true
echo

for p in $ports; do
  echo ">>> Port $p: find PIDs"
  # capture any uvicorn process that mentions --port <p>
  pids="$(ps -ef | grep -E "uvicorn|python.*-m uvicorn" | grep -F -- "--port $p" | grep -v grep | awk '{print $2}' | tr '\n' ' ' | sed 's/  */ /g' || true)"
  if [ -z "${pids:-}" ]; then
    echo "  - No PID found for --port $p"
  else
    echo "  - Killing PIDs: $pids"
    for pid in $pids; do
      kill -9 "$pid" >/dev/null 2>&1 || true
    done
  fi
  echo
done

echo ">>> After kill, remaining uvicorn candidates:"
ps -ef | grep -E "uvicorn|python.*-m uvicorn|app\.main:app" | grep -v grep || true
echo

echo ">>> Quick port probes:"
for p in $ports; do
  if curl -fsS "http://127.0.0.1:${p}/healthz" >/dev/null 2>&1; then
    echo "  - Port $p still responds to /healthz (STILL RUNNING)"
  else
    echo "  - Port $p no response (FREE/DOWN)"
  fi
done

echo "DONE"
