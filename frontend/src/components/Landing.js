import { jsx as _jsx, jsxs as _jsxs } from "react/jsx-runtime";
import { useEffect, useState } from "react";
import { playChime } from "./sound";
export default function Landing(p) {
    const [played, setPlayed] = useState(false);
    useEffect(() => {
        const t = setTimeout(() => {
            if (!played) {
                playChime();
                setPlayed(true);
            }
        }, 150);
        return () => clearTimeout(t);
    }, [played]);
    const ready = Boolean(p.keys.openaiKey?.trim());
    return (_jsx("div", { className: "landing", children: _jsxs("div", { className: "landingCard glass", children: [_jsxs("div", { className: "hero", children: [_jsx("div", { className: "quote", children: "\"\u0648\u064E\u0641\u064E\u0648\u0652\u0642\u064E \u0643\u064F\u0644\u0651\u0650 \u0630\u0650\u064A \u0639\u0650\u0644\u0652\u0645\u064D \u0639\u064E\u0644\u0650\u064A\u0645\u064C\"" }), _jsx("h1", { style: { marginTop: 10 }, children: "Station \u2014 Official Console" }), _jsx("p", { children: "Landing + Dashboard in one UI. Keys stored in LocalStorage. Backend connectivity + notifications wiring prepared." }), _jsxs("div", { className: "heroFooter", children: [_jsx("button", { className: "btn btnPrimary", onClick: p.onOpenSettings, children: "Open Settings (Keys)" }), _jsx("button", { className: "btn " + (ready ? "btnPrimary" : ""), onClick: p.onEnter, disabled: !ready, title: ready ? "Enter dashboard" : "Set OpenAI key first", children: "Enter Dashboard" }), !ready ? _jsx("span", { className: "pill", children: "OpenAI key required to activate" }) : _jsx("span", { className: "pill", style: { color: "rgba(61,220,151,.9)" }, children: "Activated" })] })] }), _jsxs("div", { className: "animBox", children: [_jsx("div", { className: "dwarf", title: "Armored Dwarf (5s animation)", children: _jsx("div", { className: "dwarfInner", children: "DWARF" }) }), _jsx("div", { style: { position: "absolute", bottom: 12, left: 12, right: 12, color: "rgba(255,255,255,.70)", fontSize: 12, lineHeight: 1.5 }, children: "Cartoon movement runs once (5 seconds) on entry. Chime plays on load." })] })] }) }));
}
