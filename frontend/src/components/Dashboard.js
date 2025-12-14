import { jsx as _jsx, jsxs as _jsxs } from "react/jsx-runtime";
import { useEffect, useMemo, useRef, useState } from "react";
import { API_BASE, jget, jpost } from "./api";
export default function Dashboard(p) {
    const [health, setHealth] = useState(null);
    const [err, setErr] = useState("");
    const [msg, setMsg] = useState("");
    const [chat, setChat] = useState([
        { role: "system", text: "Station online. Dashboard loaded.", ts: Date.now() },
    ]);
    const [events] = useState("(events wiring pending)");
    const logRef = useRef(null);
    const apiHint = useMemo(() => API_BASE, []);
    useEffect(() => {
        (async () => {
            try {
                setErr("");
                const h = await jget("/health");
                setHealth(h);
            }
            catch (e) {
                setErr(String(e?.message || e));
            }
        })();
    }, []);
    useEffect(() => {
        if (logRef.current)
            logRef.current.scrollTop = logRef.current.scrollHeight;
    }, [chat]);
    useEffect(() => {
        // Clear chat signal from top bar
        if (p.clearSignal > 0) {
            setChat([{ role: "system", text: "Chat cleared.", ts: Date.now() }]);
        }
    }, [p.clearSignal]);
    async function send() {
        const t = msg.trim();
        if (!t)
            return;
        setMsg("");
        const next = [...chat, { role: "user", text: t, ts: Date.now() }];
        setChat(next);
        // Backend chat endpoint is optional. If not available, keep local.
        try {
            const r = await jpost("/chat", { text: t, key: p.keys.openaiKey || "" });
            const out = r?.answer || r?.text || JSON.stringify(r);
            setChat((c) => [...c, { role: "system", text: String(out), ts: Date.now() }]);
        }
        catch (e) {
            setChat((c) => [...c, { role: "system", text: "[stub] Backend /chat not available. Message stored locally.", ts: Date.now() }]);
        }
    }
    return (_jsxs("div", { className: "grid2", style: { height: "100%" }, children: [_jsxs("div", { className: "panel", children: [_jsxs("div", { className: "panelHeader", children: [_jsx("h3", { children: "Chat Console" }), _jsxs("span", { children: ["Backend: ", apiHint] })] }), _jsxs("div", { className: "chatWrap", children: [_jsx("div", { className: "chatLog", ref: logRef, children: chat.map((m, i) => (_jsxs("div", { className: "msg " + (m.role === "user" ? "msgUser" : "msgSys"), children: [_jsxs("div", { className: "msgMeta", children: [m.role.toUpperCase(), " \u2022 ", new Date(m.ts).toLocaleTimeString()] }), _jsx("div", { style: { whiteSpace: "pre-wrap" }, children: m.text })] }, i))) }), _jsxs("div", { className: "chatInputRow", children: [_jsx("textarea", { value: msg, onChange: (e) => setMsg(e.target.value), placeholder: "Type here... (Windows-style input bar)", onKeyDown: (e) => {
                                            if (e.key === "Enter" && !e.shiftKey) {
                                                e.preventDefault();
                                                void send();
                                            }
                                        } }), _jsx("button", { className: "btn btnPrimary", onClick: () => void send(), children: "Send" })] })] })] }), _jsxs("div", { className: "rightCol", children: [_jsxs("div", { className: "panel", children: [_jsxs("div", { className: "panelHeader", children: [_jsx("h3", { children: "Status" }), _jsx("span", { children: err ? "Error" : "OK" })] }), _jsxs("div", { className: "kv", children: [_jsxs("div", { className: "kvRow", children: [_jsx("b", { children: "Health" }), _jsx("code", { children: health ? "loaded" : "null" })] }), _jsxs("div", { className: "kvRow", children: [_jsx("b", { children: "Events" }), _jsx("code", { children: events })] }), _jsxs("div", { className: "kvRow", children: [_jsx("b", { children: "OpenAI Key" }), _jsx("code", { children: p.keys.openaiKey ? "set" : "missing" })] }), _jsxs("div", { className: "kvRow", children: [_jsx("b", { children: "GitHub Token" }), _jsx("code", { children: p.keys.githubToken ? "set" : "missing" })] })] }), err ? (_jsx("div", { style: { marginTop: 10, padding: 10, borderRadius: 12, border: "1px solid rgba(255,77,77,.25)", background: "rgba(255,77,77,.10)", color: "rgba(255,255,255,.88)" }, children: err })) : (_jsx("div", { style: { marginTop: 10, padding: 10, borderRadius: 12, border: "1px solid rgba(61,220,151,.22)", background: "rgba(61,220,151,.10)", color: "rgba(255,255,255,.88)" }, children: "Backend reachable. Health OK." })), _jsxs("div", { style: { marginTop: 12, display: "flex", gap: 8 }, children: [_jsx("button", { className: "btn", onClick: p.onOpenSettings, children: "Keys" }), _jsx("button", { className: "btn btnPrimary", onClick: () => {
                                            void (async () => {
                                                try {
                                                    const h = await jget("/health");
                                                    setHealth(h);
                                                    setErr("");
                                                }
                                                catch (e) {
                                                    setErr(String(e?.message || e));
                                                }
                                            })();
                                        }, children: "Refresh Health" })] })] }), _jsxs("div", { className: "panel", style: { flex: 1 }, children: [_jsxs("div", { className: "panelHeader", children: [_jsx("h3", { children: "Notifications" }), _jsx("span", { children: "Backend wiring ready" })] }), _jsxs("div", { style: { color: "rgba(255,255,255,.70)", fontSize: 12, lineHeight: 1.6 }, children: ["Prepared areas:", _jsxs("ul", { children: [_jsxs("li", { children: ["Polling endpoint: ", _jsx("code", { children: "/events" }), " (recommended)"] }), _jsxs("li", { children: ["WebSocket: ", _jsx("code", { children: "/ws" }), " (optional)"] }), _jsxs("li", { children: ["Push alerts: ", _jsx("code", { children: "/notify" }), " (optional)"] })] }), "When backend is ready, this panel becomes live."] })] })] })] }));
}
