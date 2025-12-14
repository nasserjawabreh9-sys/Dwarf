import { jsx as _jsx, jsxs as _jsxs } from "react/jsx-runtime";
import { useState } from "react";
export default function TermuxPanel() {
    const [hist, setHist] = useState([
        { ts: Date.now(), line: "Welcome to Station Termux-like Console (UI-only stub)." },
        { ts: Date.now(), line: "Type commands, keep history, copy output. No server execution." },
    ]);
    const [cmd, setCmd] = useState("");
    function runLocal() {
        const c = cmd.trim();
        if (!c)
            return;
        setCmd("");
        const out = c === "help"
            ? "Commands: help | clear | echo <text> | pwd | whoami"
            : c === "clear"
                ? "(cleared)"
                : c.startsWith("echo ")
                    ? c.slice(5)
                    : c === "pwd"
                        ? "/station_root (virtual)"
                        : c === "whoami"
                            ? "operator"
                            : `unknown command: ${c}`;
        setHist((h) => {
            if (c === "clear")
                return [{ ts: Date.now(), line: "Console cleared." }];
            return [...h, { ts: Date.now(), line: `$ ${c}` }, { ts: Date.now(), line: out }];
        });
    }
    return (_jsxs("div", { className: "panel", style: { height: "100%" }, children: [_jsxs("div", { className: "panelHeader", children: [_jsx("h3", { children: "Termux-like" }), _jsx("span", { children: "UI stub (safe)" })] }), _jsxs("div", { style: { height: "calc(100% - 48px)", display: "flex", flexDirection: "column", gap: 10 }, children: [_jsx("div", { style: { flex: 1, border: "1px solid rgba(255,255,255,.10)", borderRadius: 14, background: "rgba(0,0,0,.18)", padding: 10, overflow: "auto" }, children: hist.map((x, i) => (_jsx("div", { style: { fontFamily: "ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace", fontSize: 12, color: "rgba(255,255,255,.82)", whiteSpace: "pre-wrap" }, children: x.line }, i))) }), _jsxs("div", { style: { display: "flex", gap: 10 }, children: [_jsx("input", { value: cmd, onChange: (e) => setCmd(e.target.value), placeholder: "Type command (help/clear/echo/pwd/whoami)", style: { flex: 1, padding: 12, borderRadius: 14, border: "1px solid rgba(255,255,255,.10)", background: "rgba(0,0,0,.18)", color: "rgba(255,255,255,.9)" }, onKeyDown: (e) => {
                                    if (e.key === "Enter")
                                        runLocal();
                                } }), _jsx("button", { className: "btn btnPrimary", onClick: runLocal, children: "Run" })] })] })] }));
}
