export const DEFAULT_KEYS = {
    openaiKey: "",
    githubToken: "",
    ttsKey: "",
    webhooksUrl: "",
    ocrKey: "",
    webIntegrationKey: "",
    whatsappKey: "",
    emailSmtp: "",
    githubRepo: "",
    renderApiKey: "",
    editModeKey: "1234",
};
const K = "station.keys.v1";
export function loadKeysSafe() {
    try {
        if (typeof window === "undefined")
            return { ...DEFAULT_KEYS };
        const raw = window.localStorage.getItem(K);
        if (!raw)
            return { ...DEFAULT_KEYS };
        return { ...DEFAULT_KEYS, ...JSON.parse(raw) };
    }
    catch {
        return { ...DEFAULT_KEYS };
    }
}
export function saveKeysSafe(s) {
    try {
        if (typeof window === "undefined")
            return;
        window.localStorage.setItem(K, JSON.stringify({ ...DEFAULT_KEYS, ...s }));
    }
    catch { }
}
