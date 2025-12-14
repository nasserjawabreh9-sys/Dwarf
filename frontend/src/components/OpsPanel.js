import { jsx as _jsx, jsxs as _jsxs, Fragment as _Fragment } from "react/jsx-runtime";
import { useState } from "react";
import { jpost } from "./api";
export default function OpsPanel(p) {
    const [out, setOut] = useState("Output will appear here.");
    function guard() {
        if (!p.keys.editModeKey?.trim())
            return "Edit Mode Key missing";
        if (!p.keys.githubToken?.trim())
            return "GitHub token missing";
        if (!p.keys.githubRepo?.trim())
            return "GitHub repo missing (owner/repo)";
        return null;
    }
    async function run(action) {
        const g = guard();
        if (g) {
            setOut("Blocked by guard: " + g);
            return;
        }
        try {
            const r = await jpost(`/ops/${action}`, {
                edit_key: p.keys.editModeKey,
                keys: p.keys,
            });
            setOut(JSON.stringify(r, null, 2));
        }
        catch (e) {
            setOut("[stub] backend endpoint not available.\n" + String(e?.message || e));
        }
    }
    return (_jsxs(_Fragment, { children: [_jsxs("div", { style: { padding: 12, border: "1px solid rgba(0,0,0,0.1)", borderRadius: 12, marginBottom: 12 }, children: [_jsx("div", { style: { fontWeight: 700, marginBottom: 8 }, children: "Ops" }), _jsxs("div", { style: { display: "flex", gap: 8, flexWrap: "wrap" }, children: [_jsx("button", { onClick: async () => {
                                    const base = (p.keys.backendUrl || "").trim();
                                    const url = (base || "").replace(/\/$/, "") + "/ops/git/status";
                                    const res = await postJSON(url, {}, p.keys.editKey || "");
                                    setOut(JSON.stringify(res, null, 2));
                                }, children: "Git Status (Backend)" }), _jsx("button", { onClick: async () => {
                                    const base = (p.keys.backendUrl || "").trim();
                                    const url = (base || "").replace(/\/$/, "") + "/ops/git/push";
                                    const res = await postJSON(url, {}, p.keys.editKey || "");
                                    setOut(JSON.stringify(res, null, 2));
                                }, children: "Stage + Commit + Push (Backend)" }), _jsx("button", { onClick: async () => {
                                    const base = (p.keys.backendUrl || "").trim();
                                    const url = (base || "").replace(/\/$/, "") + "/ops/render/deploy";
                                    const res = await postJSON(url, {
                                        render_api_key: p.keys.renderApiKey || "",
                                        render_service_id: p.keys.renderServiceId || "",
                                    }, p.keys.editKey || "");
                                    setOut(JSON.stringify(res, null, 2));
                                }, children: "Trigger Render Deploy" })] }), _jsx("div", { style: { opacity: 0.7, marginTop: 8, fontSize: 12 }, children: "Uses backend ops endpoints. Requires Edit Mode Key." })] }), _jsxs("div", { className: "panel", style: { height: "100%" }, children: [_jsxs("div", { className: "panelHeader", children: [_jsx("h3", { children: "Ops Console" }), _jsx("span", { children: "Guards enabled" })] }), _jsxs("div", { style: { display: "flex", gap: 8, flexWrap: "wrap" }, children: [_jsx("button", { className: "btn", onClick: () => void run("git_status"), children: "Git Status" }), _jsx("button", { className: "btn btnPrimary", onClick: () => void run("git_push"), children: "Stage + Commit + Push" }), _jsx("button", { className: "btn", onClick: () => void run("render_deploy"), children: "Deploy to Render" })] }), _jsx("pre", { style: { marginTop: 10, padding: 12, borderRadius: 14, border: "1px solid rgba(255,255,255,.10)", background: "rgba(0,0,0,.18)", overflow: "auto", height: "calc(100% - 70px)" }, children: out })] })] }));
}
// --- Station Ops helpers (auto-added) ---
async function postJSON(url, body, editKey) {
    const r = await fetch(url, {
        method: "POST",
        headers: {
            "Content-Type": "application/json",
            "x-edit-key": editKey || "",
        },
        body: JSON.stringify(body || {}),
    });
    const t = await r.text();
    try {
        return { ok: r.ok, status: r.status, json: JSON.parse(t) };
    }
    catch {
        return { ok: r.ok, status: r.status, text: t };
    }
}
