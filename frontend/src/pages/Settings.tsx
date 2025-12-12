import { useEffect, useMemo, useState } from "react";

type Keys = {
  openai_api_key: string;
  github_token: string;
  tts_key: string;
  webhooks_url: string;
  ocr_key: string;
  web_integration_key: string;
  whatsapp_key: string;
  email_smtp: string;
  github_repo: string;
  render_api_key: string;
  edit_mode_key: string;
};

const LS_KEY = "station.uui.keys.v1";

const emptyKeys: Keys = {
  openai_api_key: "",
  github_token: "",
  tts_key: "",
  webhooks_url: "",
  ocr_key: "",
  web_integration_key: "",
  whatsapp_key: "",
  email_smtp: "",
  github_repo: "",
  render_api_key: "",
  edit_mode_key: "1234",
};

export default function Settings() {
  const [keys, setKeys] = useState<Keys>(emptyKeys);
  const [status, setStatus] = useState<string>("");
  const [gitOut, setGitOut] = useState<string>("");
  const [openaiOut, setOpenaiOut] = useState<string>("");

  useEffect(() => {
    const raw = localStorage.getItem(LS_KEY);
    if (raw) {
      try {
        setKeys({ ...emptyKeys, ...JSON.parse(raw) });
      } catch {}
    }
  }, []);

  useEffect(() => {
    localStorage.setItem(LS_KEY, JSON.stringify(keys));
  }, [keys]);
  async function callApi(path: string, opts: RequestInit) {
    const res = await fetch(path, opts);
    const j = await res.json().catch(() => ({}));
    if (!res.ok) throw new Error(j?.error || String(res.status));
    return j;
  }



  const fields = useMemo(
    () =>
      ([
        ["openai_api_key", "OpenAI API Key"],
        ["github_token", "GitHub Token"],
        ["tts_key", "TTS Key"],
        ["webhooks_url", "Webhooks URL"],
        ["ocr_key", "OCR Key"],
        ["web_integration_key", "Web Integration Key"],
        ["whatsapp_key", "WhatsApp Key"],
        ["email_smtp", "Email SMTP (string)"],
        ["github_repo", "GitHub Repo (owner/repo)"],
        ["render_api_key", "Render API Key"],
        ["edit_mode_key", "Edit Mode Key (required for Ops)"],
      ] as const),
    []
  );

  async function saveToBackend() {
    setStatus("Saving to backend...");
    setGitOut("");
    try {
      const res = await fetch("/api/config/uui", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ keys }),
      });
      const j = await res.json().catch(() => ({}));
      if (!res.ok) throw new Error(j?.error || String(res.status));
      setGitOut(JSON.stringify(j, null, 2));
      setStatus("Saved to backend OK.");
    } catch (e: any) {
      setStatus("Save failed: " + (e?.message || "unknown"));
    }
  }

  async function gitStatus() {
    setStatus("Git status...");
    setGitOut("");
    try {
      const res = await fetch("/api/ops/git/status", {
        headers: { "X-Edit-Key": keys.edit_mode_key || "" },
      });
      const j = await res.json();
      if (!res.ok) throw new Error(j?.error || String(res.status));
      setGitOut(
        "REMOTE:\n" + (j.remote || "(none)") + "\n\n" +
        "LOG:\n" + (j.log || "(none)") + "\n\n" +
        "CHANGES:\n" + (j.porcelain || "(clean)")
      );
      setStatus("Git status OK.");
    } catch (e: any) {
      setStatus("Git status failed: " + (e?.message || "unknown"));
    }
  }

  async function openaiTest() {
    setStatus('Testing OpenAI key...');
    setOpenaiOut('');
    try {
      const res = await fetch('/api/ops/openai/test', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-Edit-Key': keys.edit_mode_key || ''
        },
        body: JSON.stringify({ api_key: keys.openai_api_key || '' })
      });
      const j = await res.json();
      if (!res.ok) throw new Error(j?.error || String(res.status));
      setOpenaiOut(
        'OK\nmodels_count=' + String(j.models_count) +
        '\nmodels_sample=\n' + (Array.isArray(j.models_sample) ? j.models_sample.join('\n') : '')
      );
      setStatus('OpenAI test OK.');
    } catch (e: any) {
      setStatus('OpenAI test failed: ' + (e?.message || 'unknown'));
      setOpenaiOut(String(e?.message || 'unknown'));
    }
  }

  async function gitPush() {
    setStatus("Stage + Commit + Push...");
    setGitOut("");
    try {
      const res = await fetch("/api/ops/git/push", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-Edit-Key": keys.edit_mode_key || "",
        },
        body: JSON.stringify({ root_id: 1000, msg: "UI stage/commit/push", strict: "0" }),
      });
      const j = await res.json();
      if (!res.ok) throw new Error(j?.error || String(res.status));
      setGitOut(j.out_tail || "(no output)");
      setStatus(j.ok ? "Push OK." : "Push finished with rc=" + j.rc);
    } catch (e: any) {
      setStatus("Push failed: " + (e?.message || "unknown"));
    }
  }


  async function loadFromBackend() {
    setStatus("Loading from backend...");
    setGitOut("");
    try {
      const res = await fetch("/api/config/uui");
      const j = await res.json();
      if (!res.ok) throw new Error(j?.error || String(res.status));
      if (j?.keys) {
        setKeys((prev) => ({ ...prev, ...j.keys }));
        setStatus("Loaded from backend OK.");
      } else {
        setStatus("No keys returned from backend.");
      }
    } catch (e:any) {
      setStatus("Load failed: " + (e?.message || "unknown"));
    }
  }

  return (
    <div style={{ padding: 16, maxWidth: 920, margin: "0 auto" }}>
      <h2>Station Settings</h2>
      <p>Keys are stored in LocalStorage. You can also push them to backend. Ops endpoints require Edit Mode Key.</p>

      <div style={{ display: "grid", gap: 12 }}>
        {fields.map(([k, label]) => (
          <label key={k} style={{ display: "grid", gap: 6 }}>
            <span style={{ fontWeight: 600 }}>{label}</span>
            <input
              value={(keys as any)[k]}
              onChange={(e) => setKeys((prev) => ({ ...prev, [k]: e.target.value }))}
              placeholder={label}
              style={{
                padding: 10,
                borderRadius: 8,
                border: "1px solid #333",
                background: "#111",
                color: "#eee",
              }}
            />
          </label>
        ))}
      </div>

      <div style={{ display: "flex", gap: 10, marginTop: 14, flexWrap: "wrap" }}>
        <button
          onClick={saveToBackend}
          style={{ padding: "10px 14px", borderRadius: 10, border: "1px solid #444", background: "#1b1b1b", color: "#eee" }}
        >
          Save to Backend
        </button>

        <button
          onClick={gitStatus}
          style={{ padding: "10px 14px", borderRadius: 10, border: "1px solid #444", background: "#1b1b1b", color: "#eee" }}
        >
          Git Status (Backend)
        </button>

        <button
          onClick={gitPush}
          style={{ padding: "10px 14px", borderRadius: 10, border: "1px solid #444", background: "#1b1b1b", color: "#eee" }}
        >
          Stage + Commit + Push (Backend)
        </button>

        <button
          onClick={loadFromBackend}
          style={{ padding: "10px 14px", borderRadius: 10, border: "1px solid #444", background: "#1b1b1b", color: "#eee" }}
        >
          Load from Backend
        </button>

        <span style={{ opacity: 0.85, alignSelf: "center" }}>{status}</span>
      </div>

      <pre
        style={{
          marginTop: 14,
          padding: 12,
          borderRadius: 10,
          border: "1px solid #333",
          background: "#0e0e0e",
          color: "#ddd",
          whiteSpace: "pre-wrap",
        }}
      >
        {gitOut || "Output will appear here.
      {/* SENSES_AND_HOOKS_PANEL__R9200 */
      {/* TERMUX_CONSOLE_PANEL__R9800 */}
}
      <div className="mt-6 rounded-xl border p-4">
        <div className="text-lg font-semibold mb-2">Console (Termux-like)</div>
        <div className="text-sm opacity-80 mb-2">Calls backend: GET /api/ops/allowed, POST /api/ops/exec (Edit Key required)</div>

        <div className="flex flex-wrap gap-2">
          <button className="rounded bg-black text-white px-3 py-1"
            onClick={async () => {
              try{
                const j = await callApi("/api/ops/allowed", { method:"GET" });
                setStatus("OPS allowed: " + JSON.stringify(j));
              }catch(e:any){ setStatus("OPS allowed FAIL: " + (e?.message||"unknown")); }
            }}
          >Allowed</button>

          <button className="rounded bg-black text-white px-3 py-1"
            onClick={async () => {
              try{
                const j = await callApi("/api/ops/exec", {
                  method:"POST",
                  headers:{ "Content-Type":"application/json", "X-Edit-Key": keys.edit_mode_key || "" },
                  body: JSON.stringify({ name:"git_status" })
                });
                setStatus("OPS git_status: " + JSON.stringify(j.entry));
              }catch(e:any){ setStatus("OPS exec FAIL: " + (e?.message||"unknown")); }
            }}
          >git status</button>

          <button className="rounded bg-black text-white px-3 py-1"
            onClick={async () => {
              try{
                const j = await callApi("/api/ops/exec", {
                  method:"POST",
                  headers:{ "Content-Type":"application/json", "X-Edit-Key": keys.edit_mode_key || "" },
                  body: JSON.stringify({ name:"git_log" })
                });
                setStatus("OPS git_log: " + (j.entry.stdout || ""));
              }catch(e:any){ setStatus("OPS exec FAIL: " + (e?.message||"unknown")); }
            }}
          >git log</button>
        </div>
      </div>
}
      <div className="mt-6 grid gap-4 md:grid-cols-2">
        <div className="rounded-xl border p-4">
          <div className="text-lg font-semibold mb-2">Senses (Backend)</div>

          <div className="text-sm opacity-80 mb-2">POST /api/senses/text</div>
          <div className="flex gap-2">
            <input className="w-full rounded border px-2 py-1"
              placeholder='{"text":"hello"}'
              value={(window as any).__sense_text_payload || `{"text":"hello"}`}
              onChange={(e) => ((window as any).__sense_text_payload = e.target.value)}
            />
            <button className="rounded bg-black text-white px-3 py-1"
              onClick={async () => {
                try{
                  const payload = JSON.parse((window as any).__sense_text_payload || `{"text":"hello"}`);
                  const j = await callApi("/api/senses/text", {
                    method:"POST",
                    headers:{ "Content-Type":"application/json" },
                    body: JSON.stringify(payload)
                  });
                  setStatus("SENSE text OK: " + JSON.stringify(j));
                }catch(e:any){ setStatus("SENSE text FAIL: " + (e?.message||"unknown")); }
              }}
            >Send</button>
          </div>

          <div className="mt-4 text-sm opacity-80 mb-2">POST /api/senses/audio (multipart field: audio)</div>
          <input id="senseAudio" type="file" accept="audio/*" className="block w-full text-sm"/>
          <button className="mt-2 rounded bg-black text-white px-3 py-1"
            onClick={async () => {
              try{
                const el = document.getElementById("senseAudio") as HTMLInputElement;
                const f = el?.files?.[0];
                const fd = new FormData();
                if (f) fd.append("audio", f);
                const res = await fetch("/api/senses/audio", { method:"POST", body: fd });
                const j = await res.json().catch(()=>({}));
                if(!res.ok) throw new Error(j?.error || String(res.status));
                setStatus("SENSE audio OK: " + JSON.stringify(j));
              }catch(e:any){ setStatus("SENSE audio FAIL: " + (e?.message||"unknown")); }
            }}
          >Upload Audio</button>

          <div className="mt-4 text-sm opacity-80 mb-2">POST /api/senses/image (multipart field: image)</div>
          <input id="senseImage" type="file" accept="image/*" className="block w-full text-sm"/>
          <button className="mt-2 rounded bg-black text-white px-3 py-1"
            onClick={async () => {
              try{
                const el = document.getElementById("senseImage") as HTMLInputElement;
                const f = el?.files?.[0];
                const fd = new FormData();
                if (f) fd.append("image", f);
                const res = await fetch("/api/senses/image", { method:"POST", body: fd });
                const j = await res.json().catch(()=>({}));
                if(!res.ok) throw new Error(j?.error || String(res.status));
                setStatus("SENSE image OK: " + JSON.stringify(j));
              }catch(e:any){ setStatus("SENSE image FAIL: " + (e?.message||"unknown")); }
            }}
          >Upload Image</button>

          <div className="mt-4 text-sm opacity-80 mb-2">POST /api/senses/video (multipart field: video)</div>
          <input id="senseVideo" type="file" accept="video/*" className="block w-full text-sm"/>
          <button className="mt-2 rounded bg-black text-white px-3 py-1"
            onClick={async () => {
              try{
                const el = document.getElementById("senseVideo") as HTMLInputElement;
                const f = el?.files?.[0];
                const fd = new FormData();
                if (f) fd.append("video", f);
                const res = await fetch("/api/senses/video", { method:"POST", body: fd });
                const j = await res.json().catch(()=>({}));
                if(!res.ok) throw new Error(j?.error || String(res.status));
                setStatus("SENSE video OK: " + JSON.stringify(j));
              }catch(e:any){ setStatus("SENSE video FAIL: " + (e?.message||"unknown")); }
            }}
          >Upload Video</button>
        </div>

        <div className="rounded-xl border p-4">
          <div className="text-lg font-semibold mb-2">Hooks (Protected by Edit Key)</div>
          <div className="text-sm opacity-80 mb-2">Headers: X-Edit-Key = Edit Mode Key</div>

          <div className="text-sm opacity-80 mb-2">POST /api/hooks/email</div>
          <button className="rounded bg-black text-white px-3 py-1"
            onClick={async () => {
              try{
                const payload = { to:"test@example.com", subject:"Station Hook Test", body:"Hello from Station" };
                const j = await callApi("/api/hooks/email", {
                  method:"POST",
                  headers:{ "Content-Type":"application/json", "X-Edit-Key": keys.edit_mode_key || "" },
                  body: JSON.stringify(payload)
                });
                setStatus("HOOK email OK: " + JSON.stringify(j));
              }catch(e:any){ setStatus("HOOK email FAIL: " + (e?.message||"unknown")); }
            }}
          >Test Email Hook</button>

          <div className="mt-4 text-sm opacity-80 mb-2">POST /api/hooks/whatsapp</div>
          <button className="rounded bg-black text-white px-3 py-1"
            onClick={async () => {
              try{
                const payload = { to:"+0000000000", message:"Hello from Station WhatsApp Hook" };
                const j = await callApi("/api/hooks/whatsapp", {
                  method:"POST",
                  headers:{ "Content-Type":"application/json", "X-Edit-Key": keys.edit_mode_key || "" },
                  body: JSON.stringify(payload)
                });
                setStatus("HOOK whatsapp OK: " + JSON.stringify(j));
              }catch(e:any){ setStatus("HOOK whatsapp FAIL: " + (e?.message||"unknown")); }
            }}
          >Test WhatsApp Hook</button>

          <div className="mt-4 text-sm opacity-80 mb-2">POST /api/hooks/webhook (uses keys.webhooks_url)</div>
          <button className="rounded bg-black text-white px-3 py-1"
            onClick={async () => {
              try{
                const payload = { event:"station_webhook_test", ts: new Date().toISOString() };
                const j = await callApi("/api/hooks/webhook", {
                  method:"POST",
                  headers:{ "Content-Type":"application/json", "X-Edit-Key": keys.edit_mode_key || "" },
                  body: JSON.stringify(payload)
                });
                setStatus("HOOK webhook OK: " + JSON.stringify(j));
              }catch(e:any){ setStatus("HOOK webhook FAIL: " + (e?.message||"unknown")); }
            }}
          >Fire Webhook</button>

          <div className="mt-4 text-xs opacity-70">
            Notes: Email/WhatsApp hooks are stubs الآن (ack فقط). Webhook فعلي ويرسل لـ keys.webhooks_url.
          </div>
        </div>
      </div>
"}
      </pre>
    </div>
  );
}
