import { jsx as _jsx, jsxs as _jsxs } from "react/jsx-runtime";
import { useEffect, useMemo, useState } from "react";
function lsGet(k, fallback = "") {
    try {
        return localStorage.getItem(k) || fallback;
    }
    catch {
        return fallback;
    }
}
function lsSet(k, v) {
    try {
        localStorage.setItem(k, v);
    }
    catch { }
}
async function fetchJson(url, editKey, init) {
    const headers = {
        "Accept": "application/json",
        ...init?.headers,
    };
    if (editKey)
        headers["X-Edit-Key"] = editKey;
    const res = await fetch(url, { ...init, headers });
    const ct = res.headers.get("content-type") || "";
    const text = await res.text();
    let body = text;
    if (ct.includes("application/json")) {
        try {
            body = JSON.parse(text);
        }
        catch {
            body = { raw: text };
        }
    }
    if (!res.ok) {
        throw new Error(`HTTP ${res.status} ${res.statusText}: ${typeof body === "string" ? body : JSON.stringify(body)}`);
    }
    return body;
}
export default function OpsPanel() {
    // Runtime-configurable (NOT build-time), works on Render static site
    const defaultBackend = lsGet("STATION_BACKEND_URL") ||
        import.meta?.env?.VITE_BACKEND_URL ||
        "https://station-backend-xdfe.onrender.com";
    const [backendUrl, setBackendUrl] = useState(defaultBackend);
    const [editKey, setEditKey] = useState(lsGet("STATION_EDIT_KEY", "1234"));
    const [out, setOut] = useState("");
    const [busy, setBusy] = useState(false);
    const api = useMemo(() => {
        const base = (backendUrl || "").trim().replace(/\/+$/, "");
        return {
            base,
            healthz: `${base}/healthz`,
            docs: `${base}/docs`,
            rooms: `${base}/api/ops/rooms`,
            roomRun: (rid) => `${base}/api/ops/rooms/${encodeURIComponent(rid)}/run`,
            dynamoStart: `${base}/api/ops/dynamo/start`,
            dynamoStop: `${base}/api/ops/dynamo/stop`,
            dynamoStatus: `${base}/api/ops/dynamo/status`,
            logsTail: `${base}/api/ops/logs/tail`,
        };
    }, [backendUrl]);
    // One-time seed: if STATION_BACKEND_URL not set, seed it to default backend
    useEffect(() => {
        try {
            const k = "STATION_BACKEND_URL";
            const cur = localStorage.getItem(k);
            if (!cur || !cur.trim()) {
                localStorage.setItem(k, "https://station-backend-xdfe.onrender.com");
            }
        }
        catch { }
    }, []);
    useEffect(() => {
        lsSet("STATION_BACKEND_URL", backendUrl);
    }, [backendUrl]);
    useEffect(() => {
        lsSet("STATION_EDIT_KEY", editKey);
    }, [editKey]);
    async function run(label, fn) {
        setBusy(true);
        setOut(`>>> ${label}\n`);
        try {
            const data = await fn();
            setOut((prev) => prev + JSON.stringify(data, null, 2) + "\n");
        }
        catch (e) {
            setOut((prev) => prev + `ERROR: ${e?.message || String(e)}\n`);
        }
        finally {
            setBusy(false);
        }
    }
    async function getRooms() {
        return fetchJson(api.rooms, editKey);
    }
    async function runRoom(rid) {
        return fetchJson(api.roomRun(rid), editKey, { method: "POST" });
    }
    async function dynStart() {
        return fetchJson(api.dynamoStart, editKey, { method: "POST" });
    }
    async function dynStop() {
        return fetchJson(api.dynamoStop, editKey, { method: "POST" });
    }
    async function dynStatus() {
        return fetchJson(api.dynamoStatus, editKey);
    }
    async function tailLogs() {
        return fetchJson(api.logsTail, editKey);
    }
    return (_jsxs("div", { style: { border: "1px solid #233", borderRadius: 12, padding: 12, marginTop: 12 }, children: [_jsxs("div", { style: { display: "flex", gap: 10, flexWrap: "wrap", alignItems: "center" }, children: [_jsxs("div", { style: { minWidth: 240, flex: 1 }, children: [_jsx("div", { style: { fontSize: 12, opacity: 0.8 }, children: "Backend URL" }), _jsx("input", { value: backendUrl, onChange: (e) => setBackendUrl(e.target.value), placeholder: "https://station-backend-xdfe.onrender.com", style: { width: "100%", padding: 10, borderRadius: 10, border: "1px solid #345", background: "#0b1220", color: "#dbe7ff" } }), _jsxs("div", { style: { fontSize: 12, opacity: 0.8, marginTop: 6 }, children: [_jsx("a", { href: api.docs, target: "_blank", rel: "noreferrer", style: { color: "#9cc2ff" }, children: "Open /docs" }), "  |  ", _jsx("a", { href: api.healthz, target: "_blank", rel: "noreferrer", style: { color: "#9cc2ff" }, children: "Open /healthz" })] })] }), _jsxs("div", { style: { minWidth: 160 }, children: [_jsx("div", { style: { fontSize: 12, opacity: 0.8 }, children: "Edit Key (X-Edit-Key)" }), _jsx("input", { value: editKey, onChange: (e) => setEditKey(e.target.value), placeholder: "1234", style: { width: 220, padding: 10, borderRadius: 10, border: "1px solid #345", background: "#0b1220", color: "#dbe7ff" } })] }), _jsxs("div", { style: { display: "flex", gap: 8, flexWrap: "wrap" }, children: [_jsx("button", { disabled: busy, onClick: () => run("BACKEND /healthz", () => fetchJson(api.healthz, "")), children: "Healthz" }), _jsx("button", { disabled: busy, onClick: () => run("DYNAMO status", dynStatus), children: "Dynamo Status" }), _jsx("button", { disabled: busy, onClick: () => run("DYNAMO start", dynStart), children: "Dynamo Start" }), _jsx("button", { disabled: busy, onClick: () => run("DYNAMO stop", dynStop), children: "Dynamo Stop" }), _jsx("button", { disabled: busy, onClick: () => run("ROOMS list", getRooms), children: "Rooms" }), _jsx("button", { disabled: busy, onClick: async () => {
                                    const rid = prompt("Room ID to run (example: room-1)") || "";
                                    if (!rid.trim())
                                        return;
                                    run(`ROOM run: ${rid}`, () => runRoom(rid.trim()));
                                }, children: "Run Room" }), _jsx("button", { disabled: busy, onClick: () => run("LOGS tail", tailLogs), children: "Logs Tail" }), _jsx("button", { disabled: busy, onClick: () => setOut(""), children: "Clear" })] })] }), _jsx("pre", { style: {
                    marginTop: 12,
                    padding: 12,
                    borderRadius: 12,
                    border: "1px solid #234",
                    background: "#08101d",
                    color: "#dbe7ff",
                    maxHeight: 360,
                    overflow: "auto",
                    whiteSpace: "pre-wrap"
                }, children: out || "Output will appear here..." }), _jsx("style", { children: `
        button{
          padding:10px 12px;
          border-radius:10px;
          border:1px solid #345;
          background:#0b1220;
          color:#dbe7ff;
          cursor:pointer;
        }
        button:disabled{opacity:.5;cursor:not-allowed}
      ` })] }));
}
