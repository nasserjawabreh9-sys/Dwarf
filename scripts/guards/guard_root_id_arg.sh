#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
RID="${1:-}"
[ -n "$RID" ] || { echo "GUARD_ROOT_ID_MISSING"; exit 40; }
echo "$RID" | grep -Eq '^[0-9]+$' || { echo "GUARD_ROOT_ID_NOT_NUMERIC"; exit 41; }
echo ">>> [guard_root_id_arg] OK root_id=$RID"
