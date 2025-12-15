import { jsx as _jsx, jsxs as _jsxs } from "react/jsx-runtime";
import { useEffect, useMemo, useState } from "react";
import { backendBase, getJSON, postJSON } from "./api";
import StatusPanel from "./components/status/StatusPanel";
function cls(s) { return s; }
export default function App() {
    const [tab, setTab] = useState("Landing");
    const [now, setNow] = useState(Date.now());
    useEffect(() => {
        const t = setInterval(() => setNow(Date.now()), 1000);
        return () => clearInterval(t);
    }, []);
    return (_jsxs("div", { style: { fontFamily: "system-ui, -apple-system, Segoe UI, Roboto, Arial", height: "100vh", display: "flex", flexDirection: "column" }, children: [_jsx(TopBar, { tab: tab, setTab: setTab, now: now }), _jsxs("div", { style: { display: "flex", flex: 1, minHeight: 0 }, children: [_jsx(SideBar, { tab: tab, setTab: setTab }), _jsxs("div", { style: { flex: 1, minHeight: 0, background: "#0b1220", color: "#e8eefc" }, children: [tab === "Landing" && _jsx(Landing, { setTab: setTab }), tab === "Dashboard" && _jsx(Dashboard, {}), tab === "Settings" && _jsx(Settings, {}), tab === "Console" && _jsx(Console, {})] })] }), _jsx(StatusBar, {}), _jsxs("div", { style: { position: "fixed", right: 10, bottom: 40, fontSize: 11, opacity: 0.6 }, children: ["Backend: ", backendBase] })] }));
}
function TopBar({ tab, setTab, now }) {
    return (_jsxs("div", { style: { height: 44, display: "flex", alignItems: "center", justifyContent: "space-between", padding: "0 12px", background: "#0a2a66", color: "#eaf2ff", borderBottom: "1px solid rgba(255,255,255,0.1)" }, children: [_jsxs("div", { style: { display: "flex", gap: 10, alignItems: "center" }, children: [_jsx("div", { style: { width: 26, height: 26, borderRadius: 8, background: "#163b8a", display: "grid", placeItems: "center", boxShadow: "0 6px 18px rgba(0,0,0,0.35)" }, children: _jsx("span", { style: { fontWeight: 800 }, children: "S" }) }), _jsx("div", { style: { fontWeight: 700 }, children: "Station" }), _jsx("div", { style: { opacity: 0.75, fontSize: 12 }, children: "Royal Console" })] }), _jsx("div", { style: { display: "flex", gap: 8 }, children: ["Landing", "Dashboard", "Settings", "Console"].map(t => (_jsx("button", { onClick: () => setTab(t), style: {
                        height: 28, padding: "0 10px", borderRadius: 10,
                        border: "1px solid rgba(255,255,255,0.18)",
                        background: tab === t ? "rgba(255,255,255,0.18)" : "rgba(0,0,0,0.15)",
                        color: "#eaf2ff", cursor: "pointer"
                    }, children: t }, t))) }), _jsx("div", { style: { fontSize: 12, opacity: 0.75 }, children: new Date(now).toLocaleTimeString() })] }));
}
function SideBar({ tab, setTab }) {
    const items = [
        { t: "Landing", d: "Start & Demo" },
        { t: "Dashboard", d: "Health & Rooms" },
        { t: "Settings", d: "Keys & Integrations" },
        { t: "Console", d: "Ops & Logs" }
    ];
    return (_jsxs("div", { style: { width: 240, background: "#071126", color: "#e8eefc", borderRight: "1px solid rgba(255,255,255,0.08)", padding: 12, overflow: "auto" }, children: [_jsx("div", { style: { fontWeight: 800, marginBottom: 10 }, children: "Station UUI" }), items.map(it => (_jsxs("button", { onClick: () => setTab(it.t), style: {
                    width: "100%", textAlign: "left",
                    padding: "10px 10px", marginBottom: 8,
                    borderRadius: 12,
                    border: "1px solid rgba(255,255,255,0.10)",
                    background: tab === it.t ? "rgba(255,255,255,0.14)" : "rgba(0,0,0,0.12)",
                    color: "#e8eefc",
                    cursor: "pointer"
                }, children: [_jsx("div", { style: { fontWeight: 700 }, children: it.t }), _jsx("div", { style: { fontSize: 12, opacity: 0.75 }, children: it.d })] }, it.t))), _jsxs("div", { style: { marginTop: 12, padding: 10, borderRadius: 12, border: "1px dashed rgba(255,255,255,0.14)", opacity: 0.85 }, children: [_jsx("div", { style: { fontWeight: 700 }, children: "Armored Dwarf" }), _jsx("div", { style: { fontSize: 12, opacity: 0.7 }, children: "Brand slot reserved" })] })] }));
}
function Landing({ setTab }) {
    return (_jsxs("div", { style: { padding: 16 }, children: [_jsx("div", { style: { fontSize: 22, fontWeight: 800, marginBottom: 8 }, children: "Station \u2014 Royal UUI" }), _jsx("div", { style: { opacity: 0.8, marginBottom: 14 }, children: "Launchpad: health, rooms, settings keys, and ops console." }), _jsxs("div", { style: { display: "flex", gap: 10, flexWrap: "wrap" }, children: [_jsx("button", { onClick: () => setTab("Dashboard"), style: { padding: "10px 12px", borderRadius: 12, cursor: "pointer",
                            border: "1px solid rgba(255,255,255,0.18)", background: "rgba(255,255,255,0.10)", color: "#e8eefc" }, children: "Open Dashboard" }), _jsx("button", { onClick: () => setTab("Settings"), style: { padding: "10px 12px", borderRadius: 12, cursor: "pointer",
                            border: "1px solid rgba(255,255,255,0.18)", background: "rgba(255,255,255,0.10)", color: "#e8eefc" }, children: "Open Settings (Keys)" }), _jsx("button", { onClick: () => setTab("Console"), style: { padding: "10px 12px", borderRadius: 12, cursor: "pointer",
                            border: "1px solid rgba(255,255,255,0.18)", background: "rgba(255,255,255,0.10)", color: "#e8eefc" }, children: "Open Console" })] }), _jsxs("div", { style: { marginTop: 16, padding: 12, borderRadius: 14, border: "1px solid rgba(255,255,255,0.10)", background: "rgba(0,0,0,0.18)" }, children: [_jsx("div", { style: { fontWeight: 800, marginBottom: 6 }, children: "Quick status" }), _jsx(StatusPanel, {})] })] }));
}
function Dashboard() {
    const [health, setHealth] = useState(null);
    const [rooms, setRooms] = useState(null);
    const [err, setErr] = useState("");
    useEffect(() => {
        let alive = true;
        return () => { };
    }, []);
    useEffect(() => {
        let cancelled = false;
        (async () => {
            try {
                const h = await getJSON("/healthz");
                if (!cancelled)
                    setHealth(h);
            }
            catch (e) {
                if (!cancelled)
                    setErr(String(e?.message || e));
            }
            try {
                const r = await getJSON("/api/rooms");
                if (!cancelled)
                    setRooms(r);
            }
            catch (e) {
                // rooms endpoint may not exist yet; keep UI usable
            }
        })();
        return () => { cancelled = true; };
    }, []);
    return (_jsxs("div", { style: { padding: 16 }, children: [_jsx("div", { style: { fontSize: 18, fontWeight: 800, marginBottom: 10 }, children: "Dashboard" }), err && (_jsx("div", { style: { padding: 10, borderRadius: 12, border: "1px solid rgba(255,80,80,0.35)", background: "rgba(255,0,0,0.08)", marginBottom: 12 }, children: err })), _jsxs("div", { style: { display: "grid", gap: 12 }, children: [_jsx(Card, { title: "Health (/healthz)", children: _jsx("pre", { style: preStyle, children: JSON.stringify(health, null, 2) }) }), _jsxs(Card, { title: "Rooms (/api/rooms)", children: [_jsx("pre", { style: preStyle, children: JSON.stringify(rooms, null, 2) }), _jsx("div", { style: { fontSize: 12, opacity: 0.7, marginTop: 6 }, children: "Note: if /api/rooms is not implemented yet, this may stay null." })] })] })] }));
}
function Settings() {
    const defs = useMemo(() => ([
        { k: "OPENAI_API_KEY", label: "OpenAI API Key" },
        { k: "GITHUB_TOKEN", label: "GitHub Token" },
        { k: "GITHUB_REPO", label: "GitHub Repo (owner/repo)", placeholder: "owner/repo" },
        { k: "RENDER_API_KEY", label: "Render API Key" },
        { k: "RENDER_SERVICE_ID", label: "Render Service ID" },
        { k: "TTS_KEY", label: "TTS Key" },
        { k: "OCR_KEY", label: "OCR Key" },
        { k: "WEBHOOKS_URL", label: "Webhooks URL" },
        { k: "WEB_INTEGRATION_KEY", label: "Web Integration Key" },
        { k: "WHATSAPP_KEY", label: "WhatsApp Key" },
        { k: "EMAIL_SMTP", label: "Email SMTP (string)", placeholder: "smtp://user:pass@host:port" },
        { k: "STATION_EDIT_KEY", label: "Edit Mode Key (required for Ops)", placeholder: "1234" },
    ]), []);
    const [form, setForm] = useState({});
    const [status, setStatus] = useState("");
    useEffect(() => {
        const next = {};
        for (const d of defs)
            next[d.k] = localStorage.getItem(d.k) || "";
        setForm(next);
    }, [defs]);
    function setField(k, v) {
        setForm(prev => ({ ...prev, [k]: v }));
    }
    function saveLocal() {
        Object.keys(form).forEach(k => localStorage.setItem(k, String(form[k] ?? "")));
        setStatus("Saved to LocalStorage");
        setTimeout(() => setStatus(""), 1200);
    }
    async function saveBackend() {
        try {
            await postJSON("/api/settings", form);
            setStatus("Saved to Backend (/api/settings)");
        }
        catch (e) {
            setStatus("Backend save failed: " + String(e?.message || e));
        }
        finally {
            setTimeout(() => setStatus(""), 1800);
        }
    }
    async function loadBackend() {
        try {
            const data = await getJSON("/api/settings");
            const merged = { ...form };
            for (const d of defs) {
                const v = data?.[d.k];
                if (typeof v === "string")
                    merged[d.k] = v;
            }
            setForm(merged);
            setStatus("Loaded from Backend (/api/settings)");
        }
        catch (e) {
            setStatus("Backend load failed: " + String(e?.message || e));
        }
        finally {
            setTimeout(() => setStatus(""), 1800);
        }
    }
    return (_jsxs("div", { style: { padding: 16 }, children: [_jsx("div", { style: { fontSize: 18, fontWeight: 800, marginBottom: 10 }, children: "Settings" }), _jsx("div", { style: { opacity: 0.75, marginBottom: 12 }, children: "Keys are stored in LocalStorage. You can also push them to backend if the endpoint exists." }), _jsxs("div", { style: { display: "flex", gap: 10, marginBottom: 12, flexWrap: "wrap" }, children: [_jsx("button", { onClick: saveLocal, style: btnStyle, children: "Save Local" }), _jsx("button", { onClick: saveBackend, style: btnStyle, children: "Save to Backend" }), _jsx("button", { onClick: loadBackend, style: btnStyle, children: "Load from Backend" }), status && _jsx("div", { style: { alignSelf: "center", fontSize: 12, opacity: 0.85 }, children: status })] }), _jsx("div", { style: { display: "grid", gap: 10 }, children: defs.map(d => (_jsxs("div", { style: { padding: 12, borderRadius: 14, border: "1px solid rgba(255,255,255,0.10)", background: "rgba(0,0,0,0.18)" }, children: [_jsx("div", { style: { fontWeight: 700, marginBottom: 6 }, children: d.label }), _jsx("input", { value: form[d.k] || "", onChange: (e) => setField(d.k, e.target.value), placeholder: d.placeholder || d.k, style: { width: "100%", padding: "10px 10px", borderRadius: 12, border: "1px solid rgba(255,255,255,0.14)", background: "rgba(255,255,255,0.06)", color: "#e8eefc" } }), _jsx("div", { style: { fontSize: 12, opacity: 0.6, marginTop: 6 }, children: d.k })] }, d.k))) })] }));
}
function Console() {
    const [out, setOut] = useState("");
    async function ping() {
        try {
            const h = await getJSON("/healthz");
            setOut(JSON.stringify(h, null, 2));
        }
        catch (e) {
            setOut("Ping failed: " + String(e?.message || e));
        }
    }
    async function rooms() {
        try {
            const r = await getJSON("/api/rooms");
            setOut(JSON.stringify(r, null, 2));
        }
        catch (e) {
            setOut("Rooms failed: " + String(e?.message || e));
        }
    }
    async function ops() {
        try {
            const r = await getJSON("/api/ops/logs");
            setOut(JSON.stringify(r, null, 2));
        }
        catch (e) {
            setOut("Ops logs failed: " + String(e?.message || e));
        }
    }
    return (_jsxs("div", { style: { padding: 16 }, children: [_jsx("div", { style: { fontSize: 18, fontWeight: 800, marginBottom: 10 }, children: "Console" }), _jsxs("div", { style: { display: "flex", gap: 10, marginBottom: 12, flexWrap: "wrap" }, children: [_jsx("button", { onClick: ping, style: btnStyle, children: "Ping /healthz" }), _jsx("button", { onClick: rooms, style: btnStyle, children: "GET /api/rooms" }), _jsx("button", { onClick: ops, style: btnStyle, children: "GET /api/ops/logs" }), _jsx("button", { onClick: () => setOut(""), style: btnStyle, children: "Clear" })] }), _jsx("pre", { style: preStyle, children: out })] }));
}
function StatusBar() {
    return (_jsxs("div", { style: { height: 26, borderTop: "1px solid rgba(255,255,255,0.08)", background: "rgba(0,0,0,0.25)", display: "flex", alignItems: "center", justifyContent: "space-between", padding: "0 10px", fontSize: 12, opacity: 0.85 }, children: [_jsx("div", { children: "Station UI \u2014 Ready" }), _jsx("div", { children: backendBase })] }));
}
function Card({ title, children }) {
    return (_jsxs("div", { style: { padding: 12, borderRadius: 14, border: "1px solid rgba(255,255,255,0.10)", background: "rgba(0,0,0,0.18)" }, children: [_jsx("div", { style: { fontWeight: 800, marginBottom: 8 }, children: title }), children] }));
}
const btnStyle = {
    padding: "10px 12px",
    borderRadius: 12,
    cursor: "pointer",
    border: "1px solid rgba(255,255,255,0.18)",
    background: "rgba(255,255,255,0.10)",
    color: "#e8eefc"
};
const preStyle = {
    background: "rgba(0,0,0,0.25)",
    border: "1px solid rgba(255,255,255,0.10)",
    padding: 12,
    borderRadius: 12,
    overflow: "auto",
    maxHeight: 380,
    fontSize: 12,
    lineHeight: 1.35,
    color: "#e8eefc"
};
