import { jsx as _jsx, jsxs as _jsxs } from "react/jsx-runtime";
import { useEffect, useState } from "react";
import { jget, jpost } from "../api";
export default function RoomsPanel() {
    const [rooms, setRooms] = useState([]);
    const [active, setActive] = useState("9001");
    const [title, setTitle] = useState("Room 9001");
    const [msgs, setMsgs] = useState([]);
    const [text, setText] = useState("");
    async function refresh() {
        const r = await jget("/rooms");
        setRooms(r.rooms || []);
    }
    async function load(roomId) {
        setActive(roomId);
        const r = await jget(`/rooms/${roomId}/messages?limit=80`);
        setMsgs(r.messages || []);
    }
    useEffect(() => {
        void refresh();
        void load(active);
    }, []);
    async function ensure() {
        await jpost("/rooms/ensure", { room_id: active, title });
        await refresh();
    }
    async function rename() {
        await jpost("/rooms/rename", { room_id: active, title });
        await refresh();
    }
    async function send(role) {
        const t = text.trim();
        if (!t)
            return;
        setText("");
        await jpost(`/rooms/${active}/messages`, { role, text: t });
        await load(active);
    }
    return (_jsxs("div", { className: "panel", style: { height: "100%" }, children: [_jsxs("div", { className: "panelHeader", children: [_jsx("h3", { children: "Rooms" }), _jsx("span", { children: "SQLite-backed" })] }), _jsxs("div", { style: { display: "grid", gridTemplateColumns: "280px 1fr", gap: 10, height: "calc(100% - 40px)" }, children: [_jsxs("div", { style: { border: "1px solid rgba(255,255,255,.10)", borderRadius: 14, background: "rgba(0,0,0,.18)", overflow: "auto" }, children: [_jsx("div", { style: { padding: 10, display: "flex", gap: 8 }, children: _jsx("input", { value: active, onChange: (e) => setActive(e.target.value), placeholder: "room_id", style: { flex: 1, padding: 10, borderRadius: 12, border: "1px solid rgba(255,255,255,.10)", background: "rgba(0,0,0,.15)", color: "rgba(255,255,255,.9)" } }) }), _jsx("div", { style: { padding: 10, display: "flex", gap: 8 }, children: _jsx("input", { value: title, onChange: (e) => setTitle(e.target.value), placeholder: "title", style: { flex: 1, padding: 10, borderRadius: 12, border: "1px solid rgba(255,255,255,.10)", background: "rgba(0,0,0,.15)", color: "rgba(255,255,255,.9)" } }) }), _jsxs("div", { style: { padding: 10, display: "flex", gap: 8, flexWrap: "wrap" }, children: [_jsx("button", { className: "btn btnPrimary", onClick: () => void ensure(), children: "Ensure" }), _jsx("button", { className: "btn", onClick: () => void rename(), children: "Rename" }), _jsx("button", { className: "btn", onClick: () => void refresh(), children: "Refresh" }), _jsx("button", { className: "btn", onClick: () => void load(active), children: "Load" })] }), _jsxs("div", { style: { padding: 10, borderTop: "1px solid rgba(255,255,255,.08)" }, children: [_jsx("div", { style: { color: "rgba(255,255,255,.65)", fontSize: 12, marginBottom: 6 }, children: "Known rooms" }), rooms.map((r) => (_jsxs("div", { onClick: () => void load(r.id), style: {
                                            padding: "10px 10px",
                                            borderRadius: 12,
                                            cursor: "pointer",
                                            marginBottom: 6,
                                            border: "1px solid rgba(255,255,255,.08)",
                                            background: r.id === active ? "rgba(42,167,255,.14)" : "rgba(0,0,0,.12)",
                                        }, children: [_jsx("b", { style: { fontSize: 13 }, children: r.title }), _jsx("div", { style: { color: "rgba(255,255,255,.55)", fontSize: 11 }, children: r.id })] }, r.id)))] })] }), _jsxs("div", { style: { display: "flex", flexDirection: "column", gap: 10, height: "100%" }, children: [_jsx("div", { style: { flex: 1, border: "1px solid rgba(255,255,255,.10)", borderRadius: 14, background: "rgba(0,0,0,.18)", overflow: "auto", padding: 10 }, children: msgs.map((m) => (_jsxs("div", { style: { marginBottom: 10 }, children: [_jsxs("div", { style: { color: "rgba(255,255,255,.55)", fontSize: 11 }, children: [m.role.toUpperCase(), " \u2022 ", new Date(m.created_at).toLocaleString()] }), _jsx("div", { style: { whiteSpace: "pre-wrap" }, children: m.text })] }, m.id))) }), _jsxs("div", { style: { display: "flex", gap: 10 }, children: [_jsx("textarea", { value: text, onChange: (e) => setText(e.target.value), placeholder: "Write message to room...", style: { flex: 1, height: 56, padding: 10, borderRadius: 14, border: "1px solid rgba(255,255,255,.10)", background: "rgba(0,0,0,.18)", color: "rgba(255,255,255,.9)" } }), _jsx("button", { className: "btn btnPrimary", onClick: () => void send("user"), children: "Send" })] })] })] })] }));
}
