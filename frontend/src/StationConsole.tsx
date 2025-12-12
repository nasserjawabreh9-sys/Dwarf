import React, { useEffect, useMemo, useState } from "react";

const API = (import.meta as any).env?.VITE_BACKEND_URL || "http://127.0.0.1:8000";

async function jget(path: string) {
  const r = await fetch(`${API}${path}`, { method: "GET" });
  if (!r.ok) throw new Error(`${path} -> ${r.status}`);
  return await r.json();
}

export default function StationConsole() {
  const [health, setHealth] = useState<any>(null);
  const [err, setErr] = useState<string>("");
  const [rootId, setRootId] = useState<string>("9001");
  const [msg, setMsg] = useState<string>("[UI] official console push");
  const [events, setEvents] = useState<string>("(events will be wired next)");

  const apiHint = useMemo(() => API, []);

  useEffect(() => {
    (async () => {
      try {
        setErr("");
        const h = await jget("/health");
        setHealth(h);
      } catch (e: any) {
        setErr(String(e?.message || e));
      }
    })();
  }, []);

  return (
    <div style={{ fontFamily: "system-ui", padding: 16, maxWidth: 980, margin: "0 auto" }}>
      <h1 style={{ margin: "12px 0 6px" }}>Station — Official Console</h1>
      <div style={{ opacity: 0.75, marginBottom: 16 }}>Backend: {apiHint}</div>

      <div style={{ border: "1px solid #ddd", borderRadius: 12, padding: 12, marginBottom: 12 }}>
        <h2 style={{ marginTop: 0 }}>Health</h2>
        {err ? <div style={{ color: "crimson" }}>{err}</div> : <pre style={{ margin: 0 }}>{JSON.stringify(health, null, 2)}</pre>}
      </div>

      <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 12 }}>
        <div style={{ border: "1px solid #ddd", borderRadius: 12, padding: 12 }}>
          <h2 style={{ marginTop: 0 }}>Ops</h2>
          <div style={{ display: "grid", gap: 8 }}>
            <label>
              Root ID
              <input value={rootId} onChange={(e) => setRootId(e.target.value)} style={{ width: "100%", padding: 10, borderRadius: 10, border: "1px solid #ccc" }} />
            </label>
            <label>
              Commit message
              <input value={msg} onChange={(e) => setMsg(e.target.value)} style={{ width: "100%", padding: 10, borderRadius: 10, border: "1px solid #ccc" }} />
            </label>

            <div style={{ fontSize: 13, opacity: 0.7 }}>
              Wiring buttons to backend ops endpoints will be next step (requires Edit Mode Key).
            </div>
          </div>
        </div>

        <div style={{ border: "1px solid #ddd", borderRadius: 12, padding: 12 }}>
          <h2 style={{ marginTop: 0 }}>Dynamo Events</h2>
          <pre style={{ margin: 0, whiteSpace: "pre-wrap" }}>{events}</pre>
          <div style={{ fontSize: 13, opacity: 0.7, marginTop: 8 }}>
            Next: add backend endpoint to tail station_meta/dynamo/events.jsonl and show it here.
          </div>
        </div>
      </div>
    </div>
  );
}
