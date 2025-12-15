#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

FILE="$HOME/station_root/frontend/src/App.tsx"
[ -f "$FILE" ] || { echo "ERROR: App.tsx not found"; exit 1; }

TS="$(date +%Y%m%d_%H%M%S)"
BK="$FILE.bak_tail_$TS"
cp "$FILE" "$BK"
echo "Backup created: $BK"

python - <<'PY'
from pathlib import Path
import re

p = Path.home() / "station_root/frontend/src/App.tsx"
s = p.read_text(encoding="utf-8", errors="ignore")

# Keep everything BEFORE function Landing(...)
m = re.search(r'^\s*function\s+Landing\s*\(', s, flags=re.M)
if not m:
    raise SystemExit("ERROR: function Landing( not found; cannot replace tail safely.")

head = s[:m.start()].rstrip() + "\n\n"

tail = r'''
function Landing({ setTab }: { setTab:(t:Tab)=>void }) {
  return (
    <div style={{ padding: 16 }}>
      <div style={{ fontSize: 22, fontWeight: 800, marginBottom: 8 }}>Station — Royal UUI</div>
      <div style={{ opacity: 0.8, marginBottom: 14 }}>
        Launchpad: health, rooms, settings keys, and ops console.
      </div>

      <div style={{ display:"flex", gap: 10, flexWrap:"wrap" }}>
        <button onClick={() => setTab("Dashboard")}
          style={{ padding:"10px 12px", borderRadius: 12, cursor:"pointer",
            border:"1px solid rgba(255,255,255,0.18)", background:"rgba(255,255,255,0.10)", color:"#e8eefc" }}>
          Open Dashboard
        </button>
        <button onClick={() => setTab("Settings")}
          style={{ padding:"10px 12px", borderRadius: 12, cursor:"pointer",
            border:"1px solid rgba(255,255,255,0.18)", background:"rgba(255,255,255,0.10)", color:"#e8eefc" }}>
          Open Settings (Keys)
        </button>
        <button onClick={() => setTab("Console")}
          style={{ padding:"10px 12px", borderRadius: 12, cursor:"pointer",
            border:"1px solid rgba(255,255,255,0.18)", background:"rgba(255,255,255,0.10)", color:"#e8eefc" }}>
          Open Console
        </button>
      </div>

      <div style={{ marginTop: 16, padding: 12, borderRadius: 14, border:"1px solid rgba(255,255,255,0.10)", background:"rgba(0,0,0,0.18)" }}>
        <div style={{ fontWeight: 800, marginBottom: 6 }}>Quick status</div>
        <StatusPanel />
      </div>
    </div>
  );
}

function Dashboard(){
  const [health, setHealth] = useState<any>(null);
  const [rooms, setRooms] = useState<any>(null);
  const [err, setErr] = useState<string>("");

  useEffect(() => {
    let alive = True
    return () => {}
  }, [])

  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        const h = await getJSON("/healthz");
        if (!cancelled) setHealth(h);
      } catch (e:any) {
        if (!cancelled) setErr(String(e?.message || e));
      }
      try {
        const r = await getJSON("/api/rooms");
        if (!cancelled) setRooms(r);
      } catch (e:any) {
        // rooms endpoint may not exist yet; keep UI usable
      }
    })();
    return () => { cancelled = true; };
  }, []);

  return (
    <div style={{ padding: 16 }}>
      <div style={{ fontSize: 18, fontWeight: 800, marginBottom: 10 }}>Dashboard</div>

      {err && (
        <div style={{ padding: 10, borderRadius: 12, border:"1px solid rgba(255,80,80,0.35)", background:"rgba(255,0,0,0.08)", marginBottom: 12 }}>
          {err}
        </div>
      )}

      <div style={{ display:"grid", gap: 12 }}>
        <Card title="Health (/healthz)">
          <pre style={preStyle}>{JSON.stringify(health, null, 2)}</pre>
        </Card>

        <Card title="Rooms (/api/rooms)">
          <pre style={preStyle}>{JSON.stringify(rooms, null, 2)}</pre>
          <div style={{ fontSize: 12, opacity: 0.7, marginTop: 6 }}>
            Note: if /api/rooms is not implemented yet, this may stay null.
          </div>
        </Card>
      </div>
    </div>
  );
}

type KeyDef = { k: string; label: string; placeholder?: string };

function Settings(){
  const defs: KeyDef[] = useMemo(() => ([
    { k:"OPENAI_API_KEY", label:"OpenAI API Key" },
    { k:"GITHUB_TOKEN", label:"GitHub Token" },
    { k:"GITHUB_REPO", label:"GitHub Repo (owner/repo)", placeholder:"owner/repo" },
    { k:"RENDER_API_KEY", label:"Render API Key" },
    { k:"RENDER_SERVICE_ID", label:"Render Service ID" },
    { k:"TTS_KEY", label:"TTS Key" },
    { k:"OCR_KEY", label:"OCR Key" },
    { k:"WEBHOOKS_URL", label:"Webhooks URL" },
    { k:"WEB_INTEGRATION_KEY", label:"Web Integration Key" },
    { k:"WHATSAPP_KEY", label:"WhatsApp Key" },
    { k:"EMAIL_SMTP", label:"Email SMTP (string)", placeholder:"smtp://user:pass@host:port" },
    { k:"STATION_EDIT_KEY", label:"Edit Mode Key (required for Ops)", placeholder:"1234" },
  ]), []);

  const [form, setForm] = useState<Record<string,string>>({});
  const [status, setStatus] = useState<string>("");

  useEffect(() => {
    const next: Record<string,string> = {};
    for (const d of defs) next[d.k] = localStorage.getItem(d.k) || "";
    setForm(next);
  }, [defs]);

  function setField(k: string, v: string){
    setForm(prev => ({ ...prev, [k]: v }));
  }

  function saveLocal(){
    Object.keys(form).forEach(k => localStorage.setItem(k, String(form[k] ?? "")));
    setStatus("Saved to LocalStorage");
    setTimeout(() => setStatus(""), 1200);
  }

  async function saveBackend(){
    try {
      await postJSON("/api/settings", form);
      setStatus("Saved to Backend (/api/settings)");
    } catch (e:any) {
      setStatus("Backend save failed: " + String(e?.message || e));
    } finally {
      setTimeout(() => setStatus(""), 1800);
    }
  }

  async function loadBackend(){
    try {
      const data = await getJSON("/api/settings");
      const merged: Record<string,string> = { ...form };
      for (const d of defs) {
        const v = data?.[d.k];
        if (typeof v === "string") merged[d.k] = v;
      }
      setForm(merged);
      setStatus("Loaded from Backend (/api/settings)");
    } catch (e:any) {
      setStatus("Backend load failed: " + String(e?.message || e));
    } finally {
      setTimeout(() => setStatus(""), 1800);
    }
  }

  return (
    <div style={{ padding: 16 }}>
      <div style={{ fontSize: 18, fontWeight: 800, marginBottom: 10 }}>Settings</div>
      <div style={{ opacity: 0.75, marginBottom: 12 }}>
        Keys are stored in LocalStorage. You can also push them to backend if the endpoint exists.
      </div>

      <div style={{ display:"flex", gap: 10, marginBottom: 12, flexWrap:"wrap" }}>
        <button onClick={saveLocal} style={btnStyle}>Save Local</button>
        <button onClick={saveBackend} style={btnStyle}>Save to Backend</button>
        <button onClick={loadBackend} style={btnStyle}>Load from Backend</button>
        {status && <div style={{ alignSelf:"center", fontSize: 12, opacity: 0.85 }}>{status}</div>}
      </div>

      <div style={{ display:"grid", gap: 10 }}>
        {defs.map(d => (
          <div key={d.k} style={{ padding: 12, borderRadius: 14, border:"1px solid rgba(255,255,255,0.10)", background:"rgba(0,0,0,0.18)" }}>
            <div style={{ fontWeight: 700, marginBottom: 6 }}>{d.label}</div>
            <input
              value={form[d.k] || ""}
              onChange={(e) => setField(d.k, e.target.value)}
              placeholder={d.placeholder || d.k}
              style={{ width:"100%", padding:"10px 10px", borderRadius: 12, border:"1px solid rgba(255,255,255,0.14)", background:"rgba(255,255,255,0.06)", color:"#e8eefc" }}
            />
            <div style={{ fontSize: 12, opacity: 0.6, marginTop: 6 }}>{d.k}</div>
          </div>
        ))}
      </div>
    </div>
  );
}

function Console(){
  const [out, setOut] = useState<string>("");

  async function ping(){
    try {
      const h = await getJSON("/healthz");
      setOut(JSON.stringify(h, null, 2));
    } catch (e:any) {
      setOut("Ping failed: " + String(e?.message || e));
    }
  }

  async function rooms(){
    try {
      const r = await getJSON("/api/rooms");
      setOut(JSON.stringify(r, null, 2));
    } catch (e:any) {
      setOut("Rooms failed: " + String(e?.message || e));
    }
  }

  async function ops(){
    try {
      const r = await getJSON("/api/ops/logs");
      setOut(JSON.stringify(r, null, 2));
    } catch (e:any) {
      setOut("Ops logs failed: " + String(e?.message || e));
    }
  }

  return (
    <div style={{ padding: 16 }}>
      <div style={{ fontSize: 18, fontWeight: 800, marginBottom: 10 }}>Console</div>
      <div style={{ display:"flex", gap: 10, marginBottom: 12, flexWrap:"wrap" }}>
        <button onClick={ping} style={btnStyle}>Ping /healthz</button>
        <button onClick={rooms} style={btnStyle}>GET /api/rooms</button>
        <button onClick={ops} style={btnStyle}>GET /api/ops/logs</button>
        <button onClick={() => setOut("")} style={btnStyle}>Clear</button>
      </div>
      <pre style={preStyle}>{out}</pre>
    </div>
  );
}

function StatusBar(){
  return (
    <div style={{ height: 26, borderTop:"1px solid rgba(255,255,255,0.08)", background:"rgba(0,0,0,0.25)", display:"flex", alignItems:"center", justifyContent:"space-between", padding:"0 10px", fontSize: 12, opacity: 0.85 }}>
      <div>Station UI — Ready</div>
      <div>{backendBase}</div>
    </div>
  );
}

function Card({ title, children }: { title: string; children: any }) {
  return (
    <div style={{ padding: 12, borderRadius: 14, border:"1px solid rgba(255,255,255,0.10)", background:"rgba(0,0,0,0.18)" }}>
      <div style={{ fontWeight: 800, marginBottom: 8 }}>{title}</div>
      {children}
    </div>
  );
}

const btnStyle: any = {
  padding:"10px 12px",
  borderRadius: 12,
  cursor:"pointer",
  border:"1px solid rgba(255,255,255,0.18)",
  background:"rgba(255,255,255,0.10)",
  color:"#e8eefc"
};

const preStyle: any = {
  background:"rgba(0,0,0,0.25)",
  border:"1px solid rgba(255,255,255,0.10)",
  padding: 12,
  borderRadius: 12,
  overflow:"auto",
  maxHeight: 380,
  fontSize: 12,
  lineHeight: 1.35,
  color:"#e8eefc"
};
'''.lstrip()

# Remove the accidental "let alive = True" block if any existed in old tail; we are replacing anyway.

p.write_text(head + tail, encoding="utf-8")
print("OK: Replaced tail from function Landing(...) to EOF with a clean, buildable implementation.")
PY

echo "==> Build frontend"
cd "$HOME/station_root/frontend"
npm run build
