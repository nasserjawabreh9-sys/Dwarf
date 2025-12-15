#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

FILE="$HOME/station_root/frontend/src/App.tsx"
[ -f "$FILE" ] || { echo "ERROR: App.tsx not found"; exit 1; }

TS="$(date +%Y%m%d_%H%M%S)"
BK="$FILE.bak_surgical_$TS"
cp "$FILE" "$BK"
echo "Backup created: $BK"

python - <<'PY'
from pathlib import Path
import re

p = Path.home() / "station_root/frontend/src/App.tsx"
s = p.read_text(encoding="utf-8", errors="ignore")

# --- 1) Remove the extra invalid cleanup return line anywhere (standalone line) ---
s = re.sub(r'^\s*return\s*\(\s*\)\s*=>\s*clearInterval\s*\(\s*t\s*\)\s*;\s*$\n?', '', s, flags=re.M)
s = re.sub(r'^\s*return\s*\(\s*\)\s*=>\s*clearInterval\s*\(\s*[^)]+\s*\)\s*;\s*$\n?', '', s, flags=re.M)

# --- 2) Identify where "function Landing" starts; keep everything from there downward ---
m = re.search(r'^\s*function\s+Landing\s*\(', s, flags=re.M)
tail = s[m.start():] if m else ""

# --- 3) Rebuild a correct head (imports + App + TopBar + SideBar) ---
head = """import { useEffect, useMemo, useState } from "react";
import { backendBase, getJSON, postJSON } from "./api";

import StatusPanel from "./components/status/StatusPanel";

type Tab = "Landing" | "Dashboard" | "Settings" | "Console";

function cls(s: string) { return s; }

export default function App() {
  const [tab, setTab] = useState<Tab>("Landing");
  const [now, setNow] = useState<number>(Date.now());

  useEffect(() => {
    const t = setInterval(() => setNow(Date.now()), 1000);
    return () => clearInterval(t);
  }, []);

  return (
    <div style={{ fontFamily: "system-ui, -apple-system, Segoe UI, Roboto, Arial", height: "100vh", display: "flex", flexDirection: "column" }}>
      <TopBar tab={tab} setTab={setTab} now={now} />
      <div style={{ display: "flex", flex: 1, minHeight: 0 }}>
        <SideBar tab={tab} setTab={setTab} />
        <div style={{ flex: 1, minHeight: 0, background: "#0b1220", color: "#e8eefc" }}>
          {tab === "Landing" && <Landing setTab={setTab} />}
          {tab === "Dashboard" && <Dashboard />}
          {tab === "Settings" && <Settings />}
          {tab === "Console" && <Console />}
        </div>
      </div>
      <StatusBar />
      <div style={{ position:"fixed", right: 10, bottom: 40, fontSize: 11, opacity: 0.6 }}>
        Backend: {backendBase}
      </div>
    </div>
  );
}

function TopBar({ tab, setTab, now }: { tab: Tab; setTab: (t:Tab)=>void; now:number; }) {
  return (
    <div style={{ height: 44, display:"flex", alignItems:"center", justifyContent:"space-between", padding:"0 12px", background:"#0a2a66", color:"#eaf2ff", borderBottom:"1px solid rgba(255,255,255,0.1)" }}>
      <div style={{ display:"flex", gap:10, alignItems:"center" }}>
        <div style={{ width: 26, height: 26, borderRadius: 8, background:"#163b8a", display:"grid", placeItems:"center", boxShadow:"0 6px 18px rgba(0,0,0,0.35)" }}>
          <span style={{ fontWeight: 800 }}>S</span>
        </div>
        <div style={{ fontWeight: 700 }}>Station</div>
        <div style={{ opacity: 0.75, fontSize: 12 }}>Royal Console</div>
      </div>

      <div style={{ display:"flex", gap:8 }}>
        {(["Landing","Dashboard","Settings","Console"] as Tab[]).map(t => (
          <button key={t}
            onClick={() => setTab(t)}
            style={{
              height: 28, padding:"0 10px", borderRadius: 10,
              border: "1px solid rgba(255,255,255,0.18)",
              background: tab===t ? "rgba(255,255,255,0.18)" : "rgba(0,0,0,0.15)",
              color:"#eaf2ff", cursor:"pointer"
            }}>
            {t}
          </button>
        ))}
      </div>

      <div style={{ fontSize: 12, opacity: 0.75 }}>
        {new Date(now).toLocaleTimeString()}
      </div>
    </div>
  );
}

function SideBar({ tab, setTab }: { tab: Tab; setTab:(t:Tab)=>void }) {
  const items: {t:Tab, d:string}[] = [
    { t:"Landing", d:"Start & Demo" },
    { t:"Dashboard", d:"Health & Rooms" },
    { t:"Settings", d:"Keys & Integrations" },
    { t:"Console", d:"Ops & Logs" }
  ];

  return (
    <div style={{ width: 240, background:"#071126", color:"#e8eefc", borderRight:"1px solid rgba(255,255,255,0.08)", padding: 12, overflow:"auto" }}>
      <div style={{ fontWeight: 800, marginBottom: 10 }}>Station UUI</div>
      {items.map(it => (
        <button key={it.t} onClick={() => setTab(it.t)}
          style={{
            width:"100%", textAlign:"left",
            padding:"10px 10px", marginBottom: 8,
            borderRadius: 12,
            border:"1px solid rgba(255,255,255,0.10)",
            background: tab===it.t ? "rgba(255,255,255,0.14)" : "rgba(0,0,0,0.12)",
            color:"#e8eefc",
            cursor:"pointer"
          }}>
          <div style={{ fontWeight: 700 }}>{it.t}</div>
          <div style={{ fontSize: 12, opacity: 0.75 }}>{it.d}</div>
        </button>
      ))}

      <div style={{ marginTop: 12, padding: 10, borderRadius: 12, border:"1px dashed rgba(255,255,255,0.14)", opacity: 0.85 }}>
        <div style={{ fontWeight: 700 }}>Armored Dwarf</div>
        <div style={{ fontSize: 12, opacity: 0.7 }}>Brand slot reserved</div>
      </div>
    </div>
  );
}
"""

out = head.strip() + "\n\n" + (tail.strip() + "\n" if tail else "")
p.write_text(out, encoding="utf-8")
print("OK: Rebuilt App.tsx head (App/TopBar/SideBar) and preserved tail from Landing onwards.")
PY

echo "==> Build frontend"
cd "$HOME/station_root/frontend"
npm run build
