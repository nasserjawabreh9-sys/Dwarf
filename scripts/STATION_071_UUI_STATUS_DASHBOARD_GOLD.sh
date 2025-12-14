#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="${STATION_ROOT:-$HOME/station_root}"
FRONT="$ROOT/frontend"
SRC="$FRONT/src"

cd "$ROOT"

echo "============================================"
echo "STATION_071_UUI_STATUS_DASHBOARD_GOLD"
date
echo "root: $ROOT"
echo "============================================"
echo

if [ ! -d "$FRONT" ]; then
  echo "ERROR: frontend directory missing: $FRONT"
  exit 1
fi

mkdir -p "$SRC/components/status"

cat > "$SRC/components/status/StatusPanel.tsx" <<'TSX'
import React, { useEffect, useMemo, useState } from "react";

type StatusPayload = {
  ok?: boolean;
  ts?: number;
  process?: {
    dynamo_worker?: { running?: boolean; pid?: number | null; pidfile?: string };
    loop_worker?: { running?: boolean; pid?: number | null; pidfile?: string };
  };
  files?: {
    station_db_exists?: boolean;
    agent_queue_exists?: boolean;
    dynamo_log_exists?: boolean;
    loop_log_exists?: boolean;
  };
};

function badge(ok?: boolean) {
  const base =
    "inline-flex items-center gap-2 px-3 py-1 rounded-full text-sm border";
  if (ok) return `${base} border-green-600 text-green-700`;
  return `${base} border-red-600 text-red-700`;
}

export default function StatusPanel() {
  const [data, setData] = useState<StatusPayload | null>(null);
  const [err, setErr] = useState<string>("");

  const tsHuman = useMemo(() => {
    if (!data?.ts) return "-";
    const d = new Date(data.ts * 1000);
    return d.toLocaleString();
  }, [data?.ts]);

  async function load() {
    try {
      setErr("");
      const r = await fetch("/api/status", { cache: "no-store" });
      if (!r.ok) throw new Error(`HTTP ${r.status}`);
      const j = (await r.json()) as StatusPayload;
      setData(j);
    } catch (e: any) {
      setErr(String(e?.message || e));
    }
  }

  useEffect(() => {
    load();
    const t = setInterval(load, 3000);
    return () => clearInterval(t);
  }, []);

  const dynUp = !!data?.process?.dynamo_worker?.running;
  const loopUp = !!data?.process?.loop_worker?.running;
  const dbUp = !!data?.files?.station_db_exists;
  const qUp = !!data?.files?.agent_queue_exists;

  return (
    <div style={{
      border: "1px solid rgba(0,0,0,0.1)",
      borderRadius: 16,
      padding: 16,
      background: "rgba(255,255,255,0.7)",
      backdropFilter: "blur(6px)"
    }}>
      <div style={{ display: "flex", justifyContent: "space-between", gap: 12, alignItems: "center" }}>
        <div>
          <div style={{ fontSize: 18, fontWeight: 700 }}>Station Status</div>
          <div style={{ fontSize: 12, opacity: 0.75 }}>Last update: {tsHuman}</div>
        </div>
        <button
          onClick={load}
          style={{
            padding: "8px 12px",
            borderRadius: 12,
            border: "1px solid rgba(0,0,0,0.15)",
            background: "white",
            cursor: "pointer"
          }}
        >
          Refresh
        </button>
      </div>

      {err ? (
        <div style={{ marginTop: 12, color: "#b00020" }}>
          Backend unreachable: {err}
        </div>
      ) : null}

      <div style={{ display: "grid", gridTemplateColumns: "repeat(2, minmax(0, 1fr))", gap: 12, marginTop: 14 }}>
        <div>
          <div className={badge(dynUp)}>Dynamo Worker: {dynUp ? "UP" : "DOWN"} (pid: {data?.process?.dynamo_worker?.pid ?? "-"})</div>
        </div>
        <div>
          <div className={badge(loopUp)}>Loop Worker: {loopUp ? "UP" : "DOWN"} (pid: {data?.process?.loop_worker?.pid ?? "-"})</div>
        </div>
        <div>
          <div className={badge(dbUp)}>Station DB: {dbUp ? "OK" : "MISSING"}</div>
        </div>
        <div>
          <div className={badge(qUp)}>Agent Queue: {qUp ? "OK" : "MISSING"}</div>
        </div>
      </div>

      <div style={{ marginTop: 14, fontSize: 12, opacity: 0.85 }}>
        Endpoint: <code>/api/status</code>
      </div>
    </div>
  );
}
TSX

# ---------------------------------------------------------
# Patch App.tsx: inject StatusPanel near top content (safe)
# ---------------------------------------------------------
APP_TSX="$SRC/App.tsx"
if [ ! -f "$APP_TSX" ]; then
  echo "ERROR: missing $APP_TSX"
  exit 1
fi

# Add import if missing
if ! grep -q 'components/status/StatusPanel' "$APP_TSX"; then
  # insert after first imports
  python - <<'PY' "$APP_TSX"
import sys, re, pathlib
p=pathlib.Path(sys.argv[1])
s=p.read_text(encoding="utf-8", errors="ignore")
ins='import StatusPanel from "./components/status/StatusPanel";\n'
# place after last import line
imports=list(re.finditer(r'^\s*import .*?;\s*$', s, flags=re.M))
if imports:
    pos=imports[-1].end()
    s=s[:pos]+"\n"+ins+s[pos:]
else:
    s=ins+s
p.write_text(s, encoding="utf-8")
print("patched import:", str(p))
PY
fi

# Inject component render once (safe: add near top-level return)
if ! grep -q "<StatusPanel" "$APP_TSX"; then
  python - <<'PY' "$APP_TSX"
import sys, re, pathlib
p=pathlib.Path(sys.argv[1])
s=p.read_text(encoding="utf-8", errors="ignore")

# naive but safe: insert inside first return JSX container
# look for "return (" then inject after it
m=re.search(r"return\s*\(\s*", s)
if not m:
    print("WARN: could not find return( ) to inject; skipped")
else:
    pos=m.end()
    block='\n      <div style={{ marginBottom: 12 }}>\n        <StatusPanel />\n      </div>\n'
    s=s[:pos]+block+s[pos:]
    p.write_text(s, encoding="utf-8")
    print("injected StatusPanel:", str(p))
PY
fi

echo
echo "Frontend patch done."
echo "You can run:"
echo "  cd $FRONT && npm install && npm run dev"
echo "============================================"
echo "DONE: STATION_071_UUI_STATUS_DASHBOARD_GOLD"
echo "============================================"
