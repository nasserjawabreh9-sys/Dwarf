import { jsx as _jsx, jsxs as _jsxs } from "react/jsx-runtime";
import { useEffect, useMemo, useState } from "react";
function badge(ok) {
    const base = "inline-flex items-center gap-2 px-3 py-1 rounded-full text-sm border";
    if (ok)
        return `${base} border-green-600 text-green-700`;
    return `${base} border-red-600 text-red-700`;
}
export default function StatusPanel() {
    const [data, setData] = useState(null);
    const [err, setErr] = useState("");
    const tsHuman = useMemo(() => {
        if (!data?.ts)
            return "-";
        const d = new Date(data.ts * 1000);
        return d.toLocaleString();
    }, [data?.ts]);
    async function load() {
        try {
            setErr("");
            const r = await fetch("/api/status", { cache: "no-store" });
            if (!r.ok)
                throw new Error(`HTTP ${r.status}`);
            const j = (await r.json());
            setData(j);
        }
        catch (e) {
            setErr(String(e?.message || e));
        }
    }
    useEffect(() => {
        load();
        const t = setInterval(load, 3000);
        return () => clearInterval(t);
    }, []);
    const dynUp = !!data?.process?.dynamo_worker?.running;
    const loopUp = !!data?.process?.loop_worker?.running;
    const dbUp = !!data?.files?.station_db_exists;
    const qUp = !!data?.files?.agent_queue_exists;
    return (_jsxs("div", { style: {
            border: "1px solid rgba(0,0,0,0.1)",
            borderRadius: 16,
            padding: 16,
            background: "rgba(255,255,255,0.7)",
            backdropFilter: "blur(6px)"
        }, children: [_jsxs("div", { style: { display: "flex", justifyContent: "space-between", gap: 12, alignItems: "center" }, children: [_jsxs("div", { children: [_jsx("div", { style: { fontSize: 18, fontWeight: 700 }, children: "Station Status" }), _jsxs("div", { style: { fontSize: 12, opacity: 0.75 }, children: ["Last update: ", tsHuman] })] }), _jsx("button", { onClick: load, style: {
                            padding: "8px 12px",
                            borderRadius: 12,
                            border: "1px solid rgba(0,0,0,0.15)",
                            background: "white",
                            cursor: "pointer"
                        }, children: "Refresh" })] }), err ? (_jsxs("div", { style: { marginTop: 12, color: "#b00020" }, children: ["Backend unreachable: ", err] })) : null, _jsxs("div", { style: { display: "grid", gridTemplateColumns: "repeat(2, minmax(0, 1fr))", gap: 12, marginTop: 14 }, children: [_jsx("div", { children: _jsxs("div", { className: badge(dynUp), children: ["Dynamo Worker: ", dynUp ? "UP" : "DOWN", " (pid: ", data?.process?.dynamo_worker?.pid ?? "-", ")"] }) }), _jsx("div", { children: _jsxs("div", { className: badge(loopUp), children: ["Loop Worker: ", loopUp ? "UP" : "DOWN", " (pid: ", data?.process?.loop_worker?.pid ?? "-", ")"] }) }), _jsx("div", { children: _jsxs("div", { className: badge(dbUp), children: ["Station DB: ", dbUp ? "OK" : "MISSING"] }) }), _jsx("div", { children: _jsxs("div", { className: badge(qUp), children: ["Agent Queue: ", qUp ? "OK" : "MISSING"] }) })] }), _jsxs("div", { style: { marginTop: 14, fontSize: 12, opacity: 0.85 }, children: ["Endpoint: ", _jsx("code", { children: "/api/status" })] })] }));
}
