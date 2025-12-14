import { jsx as _jsx, jsxs as _jsxs } from "react/jsx-runtime";
import { useEffect, useRef, useState } from "react";
;
export default function VoiceInput({ onText }) {
    const [supported, setSupported] = useState(false);
    const [listening, setListening] = useState(false);
    const [partial, setPartial] = useState("");
    const recogRef = useRef(null);
    useEffect(() => {
        const w = window;
        const SR = w.SpeechRecognition || w.webkitSpeechRecognition;
        if (!SR) {
            setSupported(false);
            return;
        }
        setSupported(true);
        const r = new SR();
        r.lang = "ar-SA";
        r.continuous = false;
        r.interimResults = true;
        r.onresult = (e) => {
            let finalText = "";
            let interim = "";
            for (let i = e.resultIndex; i < e.results.length; i++) {
                const t = e.results[i][0].transcript || "";
                if (e.results[i].isFinal)
                    finalText += t;
                else
                    interim += t;
            }
            setPartial(interim);
            if (finalText.trim()) {
                onText(finalText.trim());
                setPartial("");
            }
        };
        r.onend = () => {
            setListening(false);
        };
        r.onerror = () => {
            setListening(false);
        };
        recogRef.current = r;
    }, [onText]);
    const toggle = () => {
        const r = recogRef.current;
        if (!r)
            return;
        if (listening) {
            r.stop();
            setListening(false);
            return;
        }
        setPartial("");
        setListening(true);
        r.start();
    };
    if (!supported)
        return null;
    return (_jsxs("div", { style: { display: "flex", gap: 8, alignItems: "center" }, children: [_jsx("button", { onClick: toggle, className: "btn btn-sm", children: listening ? "Stop Mic" : "Mic" }), partial ? (_jsx("div", { style: { opacity: 0.8, fontSize: 12, maxWidth: 360, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }, children: partial })) : null] }));
}
