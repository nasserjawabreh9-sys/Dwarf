const BASE = import.meta.env?.VITE_BACKEND_URL || "http://127.0.0.1:8000";
export async function getJSON(path) {
    const r = await fetch(`${BASE}${path}`);
    if (!r.ok)
        throw new Error(`${r.status} ${r.statusText}`);
    return r.json();
}
export async function postJSON(path, body) {
    const r = await fetch(`${BASE}${path}`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body)
    });
    if (!r.ok)
        throw new Error(`${r.status} ${r.statusText}`);
    return r.json();
}
export const backendBase = BASE;
