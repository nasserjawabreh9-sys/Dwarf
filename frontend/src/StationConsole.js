import { jsx as _jsx, jsxs as _jsxs } from "react/jsx-runtime";
import { useMemo, useState } from "react";
import SideBar from "./components/SideBar";
import TopBar from "./components/TopBar";
import Landing from "./components/Landing";
import Dashboard from "./components/Dashboard";
import SettingsModal from "./components/SettingsModal";
import OpsPanel from "./components/OpsPanel";
import AboutPanel from "./components/AboutPanel";
import { jpost } from "./components/api";
import { loadKeysSafe, saveKeysSafe } from "./components/storage";
export default function StationConsole() {
    const [nav, setNav] = useState("landing");
    const [keys, setKeys] = useState(() => loadKeysSafe());
    const [settingsOpen, setSettingsOpen] = useState(false);
    const [clearSig, setClearSig] = useState(0);
    const [stripDismiss, setStripDismiss] = useState({});
    const [statusText, setStatusText] = useState("");
    const strips = useMemo(() => {
        const s = [];
        if (!keys.openaiKey?.trim())
            s.push({ id: "need_openai", title: "OpenAI key missing", desc: "Set OpenAI key to activate AI features.", action: "settings" });
        if (!keys.githubToken?.trim())
            s.push({ id: "need_github", title: "GitHub token missing", desc: "Set token to enable Git ops.", action: "settings" });
        if (!keys.renderApiKey?.trim())
            s.push({ id: "need_render", title: "Render API key missing", desc: "Set key if you want one-click deploy.", action: "settings" });
        return s;
    }, [keys]);
    function dismiss(id) {
        setStripDismiss((x) => ({ ...x, [id]: true }));
    }
    async function pushBackend() {
        setStatusText("Pushing to backend...");
        try {
            const r = await jpost("/keys", { keys });
            setStatusText("Saved to backend: " + (r?.ok ? "OK" : "unknown"));
        }
        catch (e) {
            setStatusText("Backend /keys not available (stub). " + String(e?.message || e));
        }
    }
    return (_jsxs("div", { className: "appRoot", children: [_jsx(TopBar, { title: "Station", subtitle: "Official Console \u2022 Blue Luxury", rightHint: `Nav: ${nav.toUpperCase()}`, onOpenSettings: () => setSettingsOpen(true), onClearChat: () => setClearSig((n) => n + 1) }), _jsxs("div", { className: "mainRow", children: [_jsx(SideBar, { active: nav, onNav: setNav }), _jsxs("div", { className: "content", children: [_jsx("div", { className: "stripStack", children: strips
                                    .filter((x) => !stripDismiss[x.id])
                                    .map((x) => (_jsxs("div", { className: "strip", children: [_jsxs("div", { className: "stripLeft", children: [_jsx("strong", { children: x.title }), _jsx("small", { children: x.desc })] }), _jsxs("div", { style: { display: "flex", gap: 8 }, children: [x.action === "settings" ? (_jsx("button", { className: "btn btnPrimary", onClick: () => setSettingsOpen(true), children: "Fix" })) : null, _jsx("button", { className: "btn", onClick: () => dismiss(x.id), children: "Hide" })] })] }, x.id))) }), _jsx("div", { style: { flex: 1, overflow: "hidden" }, children: nav === "landing" ? (_jsx(Landing, { keys: keys, onOpenSettings: () => setSettingsOpen(true), onEnter: () => setNav("dashboard") })) : nav === "dashboard" ? (_jsx(Dashboard, { keys: keys, onOpenSettings: () => setSettingsOpen(true), clearSignal: clearSig })) : nav === "ops" ? (_jsx(OpsPanel, {})) : (_jsx(AboutPanel, {})) })] })] }), _jsx(SettingsModal, { open: settingsOpen, keys: keys, onChange: setKeys, onClose: () => setSettingsOpen(false), onSaveLocal: () => {
                    saveKeysSafe(keys);
                    setStatusText("Saved locally.");
                }, onPushBackend: () => void pushBackend(), pushEnabled: Boolean(keys.editModeKey?.trim()), statusText: statusText })] }));
}
