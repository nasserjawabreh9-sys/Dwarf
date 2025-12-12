#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

RID="${1:-}"; shift || true
MSG="${1:-}"; shift || true

bash scripts/guards/guard_root_id_arg.sh "$RID"

if [ -z "$MSG" ]; then
  MSG="[R${RID}] autopush"
fi

bash scripts/ops/stage_commit_push.sh "$RID" "$MSG"
