import { jsx as _jsx, jsxs as _jsxs } from "react/jsx-runtime";
import { useEffect, useState } from "react";
import { backendBase, getJSON, postJSON } from "./api";
import StatusPanel from "./components/status/StatusPanel";
function cls(s) { return s; }
export default function App() {
    const [tab, setTab] = useState("Landing");
    const [now, setNow] = useState(Date.now());
    useEffect(() => {
        const t = setInterval(() => setNow(Date.now()), 1000);
        return (_jsx("div", { style: { marginBottom: 12 }, children: _jsx(StatusPanel, {}) }));
        return () => clearInterval(t);
    }, []);
    ;
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
    return (_jsxs("div", { style: { width: 240, background: "#07101f", borderRight: "1px solid rgba(255,255,255,0.08)", padding: 12 }, children: [_jsx("div", { style: { fontSize: 12, opacity: 0.7, marginBottom: 8 }, children: "Navigation" }), items.map(x => (_jsxs("div", { onClick: () => setTab(x.t), style: {
                    padding: "10px 10px", borderRadius: 12, cursor: "pointer",
                    background: tab === x.t ? "rgba(74,144,226,0.18)" : "transparent",
                    border: tab === x.t ? "1px solid rgba(74,144,226,0.35)" : "1px solid rgba(255,255,255,0.06)",
                    marginBottom: 8
                }, children: [_jsx("div", { style: { fontWeight: 700 }, children: x.t }), _jsx("div", { style: { fontSize: 12, opacity: 0.7 }, children: x.d })] }, x.t))), _jsxs("div", { style: { marginTop: 12, padding: 10, borderRadius: 12, border: "1px dashed rgba(255,255,255,0.14)", opacity: 0.85 }, children: [_jsx("div", { style: { fontWeight: 700 }, children: "Armored Dwarf" }), _jsx("div", { style: { fontSize: 12, opacity: 0.7 }, children: "Brand slot reserved" })] })] }));
}
function Landing({ setTab }) {
    return (_jsxs("div", { style: { padding: 18, maxWidth: 980 }, children: [_jsx("div", { style: { fontSize: 30, fontWeight: 900, letterSpacing: -0.4 }, children: "Station is Ready" }), _jsx("div", { style: { marginTop: 6, opacity: 0.8 }, children: "One UI to run backend, keys, rooms, ops, and dynamo." }), _jsxs("div", { style: { display: "grid", gridTemplateColumns: "1fr 1fr", gap: 12, marginTop: 14 }, children: [_jsx(Card, { title: "5-sec animation placeholder", desc: "You can replace this with your dwarf cartoon + audio later." }), _jsx(Card, { title: "Keys bars", desc: "Settings screen contains permanent bars for: API Key, TTS, Hooks, OCR, Web, WhatsApp, Email, GitHub, Render." })] }), _jsxs("div", { style: { marginTop: 14, display: "flex", gap: 10 }, children: [_jsx("button", { onClick: () => setTab("Settings"), style: btnPrimary, children: "Open Settings" }), _jsx("button", { onClick: () => setTab("Dashboard"), style: btnGhost, children: "Open Dashboard" }), _jsx("button", { onClick: () => setTab("Console"), style: btnGhost, children: "Open Console" })] }), _jsx("div", { style: { marginTop: 16, fontSize: 12, opacity: 0.7 }, children: "Note: animation/audio are placeholders to keep this build Termux-safe and stable." })] }));
}
function Dashboard() {
    const [health, setHealth] = useState(null);
    const [rooms, setRooms] = useState(null);
    const [err, setErr] = useState("");
    useEffect(() => {
        (async () => {
            try {
                const h = await getJSON("/healthz");
                const r = await getJSON("/api/rooms");
                setHealth(h);
                setRooms(r);
            }
            catch (e) {
                setErr(String(e?.message || e));
            }
        })();
    }, []);
    return (_jsxs("div", { style: { padding: 18, maxWidth: 980 }, children: [_jsx("div", { style: { fontSize: 22, fontWeight: 900 }, children: "Dashboard" }), err && _jsxs("div", { style: { marginTop: 10, color: "#ffb4b4" }, children: ["Error: ", err] }), _jsxs("div", { style: { display: "grid", gridTemplateColumns: "1fr 1fr", gap: 12, marginTop: 12 }, children: [_jsx(Panel, { title: "Backend Health", value: health ? "OK" : "...", body: _jsx("pre", { style: pre, children: JSON.stringify(health, null, 2) }) }), _jsx(Panel, { title: "Rooms / Guards", value: rooms ? "Loaded" : "...", body: _jsx("pre", { style: pre, children: JSON.stringify(rooms, null, 2) }) })] })] }));
}
function Settings() {
    const [form, setForm] = useState({
        openai_api_key: localStorage.getItem("openai_api_key") || "",
        github_token: localStorage.getItem("github_token") || "",
        github_repo: localStorage.getItem("github_repo") || "",
        render_api_key: localStorage.getItem("render_api_key") || "",
        render_service_id: localStorage.getItem("render_service_id") || "",
        edit_mode_key: localStorage.getItem("edit_mode_key") || "1234",
        tts_key: localStorage.getItem("tts_key") || "",
        webhooks_url: localStorage.getItem("webhooks_url") || "",
        ocr_key: localStorage.getItem("ocr_key") || "",
        web_integration_key: localStorage.getItem("web_integration_key") || "",
        whatsapp_key: localStorage.getItem("whatsapp_key") || "",
        email_smtp: localStorage.getItem("email_smtp") || ""
    });
    const [status, setStatus] = useState("");
    function saveLocal() {
        Object.keys(form).forEach(k => localStorage.setItem(k, String(form[k] ?? "")));
        setStatus("Saved to LocalStorage");
        setTimeout(() => setStatus(""), 1200);
    }
    async function saveBackend() {
        try {
            await postJSON("/api/settings", form);
            setStatus("Saved to Backend");
            setTimeout(() => setStatus(""), 1200);
        }
        catch (e) {
            setStatus("Backend error: " + (e?.message || e));
        }
    }
    async function loadBackend() {
        try {
            const r = await getJSON("/api/settings");
            setStatus("Loaded (masked) from Backend");
            console.log("backend settings", r);
            setTimeout(() => setStatus(""), 1200);
        }
        catch (e) {
            setStatus("Load error: " + (e?.message || e));
        }
    }
    return (_jsxs("div", { style: { padding: 18, maxWidth: 980 }, children: [_jsx("div", { style: { fontSize: 22, fontWeight: 900 }, children: "Station Settings" }), _jsx("div", { style: { marginTop: 6, opacity: 0.8, fontSize: 13 }, children: "Keys are stored in LocalStorage. You can also push them to backend. Ops endpoints require Edit Mode Key." }), _jsxs("div", { style: { marginTop: 12, display: "grid", gridTemplateColumns: "1fr 1fr", gap: 12 }, children: [_jsx(Field, { label: "OpenAI API Key", v: form.openai_api_key, onChange: (v) => setForm({ ...form, openai_api_key: v }), secret: true }), _jsx(Field, { label: "GitHub Token", v: form.github_token, onChange: (v) => setForm({ ...form, github_token: v }), secret: true }), _jsx(Field, { label: "GitHub Repo (owner/repo)", v: form.github_repo, onChange: (v) => setForm({ ...form, github_repo: v }) }), _jsx(Field, { label: "Render API Key", v: form.render_api_key, onChange: (v) => setForm({ ...form, render_api_key: v }), secret: true }), _jsx(Field, { label: "Render Service ID", v: form.render_service_id, onChange: (v) => setForm({ ...form, render_service_id: v }) }), _jsx(Field, { label: "Edit Mode Key (required for Ops)", v: form.edit_mode_key, onChange: (v) => setForm({ ...form, edit_mode_key: v }) })] }), _jsxs("div", { style: { marginTop: 12, display: "grid", gridTemplateColumns: "1fr 1fr", gap: 12 }, children: [_jsx(Field, { label: "TTS Key", v: form.tts_key, onChange: (v) => setForm({ ...form, tts_key: v }) }), _jsx(Field, { label: "Webhooks URL", v: form.webhooks_url, onChange: (v) => setForm({ ...form, webhooks_url: v }) }), _jsx(Field, { label: "OCR Key", v: form.ocr_key, onChange: (v) => setForm({ ...form, ocr_key: v }) }), _jsx(Field, { label: "Web Integration Key", v: form.web_integration_key, onChange: (v) => setForm({ ...form, web_integration_key: v }) }), _jsx(Field, { label: "WhatsApp Key", v: form.whatsapp_key, onChange: (v) => setForm({ ...form, whatsapp_key: v }) }), _jsx(Field, { label: "Email SMTP (string)", v: form.email_smtp, onChange: (v) => setForm({ ...form, email_smtp: v }) })] }), _jsxs("div", { style: { marginTop: 12, display: "flex", gap: 10, flexWrap: "wrap" }, children: [_jsx("button", { onClick: saveLocal, style: btnPrimary, children: "Save Local" }), _jsx("button", { onClick: saveBackend, style: btnGhost, children: "Save to Backend" }), _jsx("button", { onClick: loadBackend, style: btnGhost, children: "Load from Backend" }), _jsx("div", { style: { marginLeft: 8, fontSize: 12, opacity: 0.75, alignSelf: "center" }, children: status })] })] }));
}
function Console() {
    const [out, setOut] = useState("");
    const [editKey, setEditKey] = useState(localStorage.getItem("edit_mode_key") || "1234");
    async function gitStatus() {
        try {
            const r = await getJSON("/api/ops/git/status");
            setOut(JSON.stringify(r, null, 2));
        }
        catch (e) {
            setOut("Error: " + (e?.message || e));
        }
    }
    async function gitPush() {
        try {
            const r = await postJSON("/api/ops/git/push", { edit_mode_key: editKey, message: "station global build" });
            setOut(JSON.stringify(r, null, 2));
        }
        catch (e) {
            setOut("Error: " + (e?.message || e));
        }
    }
    async function dynamoTick() {
        try {
            const r = await postJSON("/api/dynamo/tick", {});
            setOut(JSON.stringify(r, null, 2));
        }
        catch (e) {
            setOut("Error: " + (e?.message || e));
        }
    }
    return (_jsxs("div", { style: { padding: 18, maxWidth: 980 }, children: [_jsx("div", { style: { fontSize: 22, fontWeight: 900 }, children: "Station Console" }), _jsxs("div", { style: { marginTop: 10, display: "flex", gap: 10, flexWrap: "wrap" }, children: [_jsx("button", { onClick: gitStatus, style: btnGhost, children: "Git Status (Backend)" }), _jsx("button", { onClick: gitPush, style: btnPrimary, children: "Stage + Commit + Push (Backend)" }), _jsx("button", { onClick: dynamoTick, style: btnGhost, children: "Dynamo Tick" }), _jsxs("div", { style: { display: "flex", gap: 8, alignItems: "center" }, children: [_jsx("span", { style: { fontSize: 12, opacity: 0.75 }, children: "Edit Key" }), _jsx("input", { value: editKey, onChange: (e) => { setEditKey(e.target.value); localStorage.setItem("edit_mode_key", e.target.value); }, style: { height: 28, borderRadius: 10, border: "1px solid rgba(255,255,255,0.18)", background: "rgba(0,0,0,0.25)", color: "#eaf2ff", padding: "0 10px" } })] })] }), _jsx("div", { style: { marginTop: 12 }, children: _jsx("pre", { style: pre, children: out || "Output will appear here." }) })] }));
}
function Card({ title, desc }) {
    return (_jsxs("div", { style: { padding: 14, borderRadius: 16, background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.08)" }, children: [_jsx("div", { style: { fontWeight: 900 }, children: title }), _jsx("div", { style: { marginTop: 6, opacity: 0.8, fontSize: 13 }, children: desc })] }));
}
function Panel({ title, value, body }) {
    return (_jsxs("div", { style: { padding: 14, borderRadius: 16, background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.08)" }, children: [_jsxs("div", { style: { display: "flex", justifyContent: "space-between", alignItems: "center" }, children: [_jsx("div", { style: { fontWeight: 900 }, children: title }), _jsx("div", { style: { fontSize: 12, opacity: 0.75 }, children: value })] }), _jsx("div", { style: { marginTop: 10 }, children: body })] }));
}
function Field({ label, v, onChange, secret }) {
    return (_jsxs("div", { style: { padding: 12, borderRadius: 16, background: "rgba(0,0,0,0.18)", border: "1px solid rgba(255,255,255,0.10)" }, children: [_jsx("div", { style: { fontSize: 12, opacity: 0.78 }, children: label }), _jsx("input", { value: v, type: secret ? "password" : "text", onChange: (e) => onChange(e.target.value), style: {
                    marginTop: 6, width: "100%", height: 34, padding: "0 10px",
                    borderRadius: 12, border: "1px solid rgba(255,255,255,0.18)",
                    background: "rgba(0,0,0,0.28)", color: "#eaf2ff"
                } })] }));
}
function StatusBar() {
    return (_jsxs("div", { style: { height: 30, display: "flex", alignItems: "center", justifyContent: "space-between", padding: "0 12px",
            background: "#061023", borderTop: "1px solid rgba(255,255,255,0.08)", color: "#cfe0ff", fontSize: 12 }, children: [_jsxs("div", { children: ["Station Status: ", _jsx("span", { style: { opacity: 0.85 }, children: "Ready" })] }), _jsx("div", { style: { opacity: 0.7 }, children: "Ports: 8000 / 5173" })] }));
}
const pre = {
    whiteSpace: "pre-wrap",
    wordBreak: "break-word",
    background: "rgba(0,0,0,0.35)",
    border: "1px solid rgba(255,255,255,0.10)",
    borderRadius: 14,
    padding: 12,
    minHeight: 180
};
const btnPrimary = {
    height: 34, padding: "0 12px", borderRadius: 12,
    border: "1px solid rgba(74,144,226,0.55)",
    background: "rgba(74,144,226,0.28)",
    color: "#eaf2ff", cursor: "pointer", fontWeight: 800
};
const btnGhost = {
    height: 34, padding: "0 12px", borderRadius: 12,
    border: "1px solid rgba(255,255,255,0.18)",
    background: "rgba(0,0,0,0.22)",
    color: "#eaf2ff", cursor: "pointer", fontWeight: 700
};
