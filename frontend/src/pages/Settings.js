import { jsx as _jsx, jsxs as _jsxs } from "react/jsx-runtime";
import { useEffect, useState } from "react";
import { apiGet, apiPost } from "../lib/api";
export default function Settings() {
    const [keys, setKeys] = useState({
        openai_api_key: "",
        github_token: "",
        tts_key: "",
        webhooks_url: "",
        ocr_key: "",
        web_integration_key: "",
        whatsapp_key: "",
        email_smtp: "",
        github_repo: "",
        render_api_key: "",
        edit_mode_key: "1234"
    });
    const [msg, setMsg] = useState("");
    async function load() {
        setMsg("Loading...");
        const j = await apiGet("/api/config/uui");
        setKeys(j?.keys || keys);
        setMsg("Loaded");
    }
    async function save() {
        setMsg("Saving...");
        await apiPost("/api/config/uui", { keys }, keys.edit_mode_key);
        setMsg("Saved");
    }
    useEffect(() => { load().catch(() => setMsg("Load failed")); }, []);
    return (_jsxs("div", { style: { padding: 20, maxWidth: 900 }, children: [_jsx("h2", { children: "Station Settings" }), _jsx("p", { style: { opacity: 0.8 }, children: "Keys are stored in LocalStorage (UI) + can be pushed to backend. Ops endpoints require Edit Mode Key." }), _jsx("div", { style: { display: "grid", gridTemplateColumns: "1fr 1fr", gap: 12 }, children: Object.keys(keys).map((k) => (_jsxs("label", { style: { display: "flex", flexDirection: "column", gap: 6 }, children: [_jsx("span", { children: k }), _jsx("input", { value: keys[k] ?? "", onChange: (e) => setKeys({ ...keys, [k]: e.target.value }), style: { padding: 10 } })] }, k))) }), _jsxs("div", { style: { display: "flex", gap: 10, marginTop: 16 }, children: [_jsx("button", { onClick: () => save().catch(() => setMsg("Save failed")), children: "Save to Backend" }), _jsx("button", { onClick: () => load().catch(() => setMsg("Load failed")), children: "Load from Backend" })] }), _jsx("p", { style: { marginTop: 10 }, children: msg })] }));
}
