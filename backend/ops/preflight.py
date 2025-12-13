import os, sys

SOFT_REQUIRED = ["STATION_EDIT_KEY"]
OPTIONAL_KEYS = [
  "STATION_OPENAI_API_KEY",
  "OPENAI_API_KEY",
  "GITHUB_TOKEN",
  "RENDER_API_KEY",
  "TTS_KEY",
  "OCR_KEY",
  "WEBHOOKS_URL",
  "WHATSAPP_KEY",
  "EMAIL_SMTP",
  "GITHUB_REPO",
]

def main():
  print(">>> [PREFLIGHT] Station Render Preflight")
  print("python =", sys.version.split()[0])

  missing_soft = [k for k in SOFT_REQUIRED if not os.getenv(k)]
  if missing_soft:
    print("!!! missing soft-required env:", ", ".join(missing_soft))
    print("    action: set them in Render Environment. Service can still run, but Ops may be limited.")
  else:
    print("OK soft-required env present")

  empty_optional = [k for k in OPTIONAL_KEYS if not os.getenv(k)]
  if empty_optional:
    print(".. optional keys empty (expected until you set them from UI):")
    for k in empty_optional:
      print(" -", k)

  port = os.getenv("PORT", "")
  if port:
    print("OK PORT =", port)
  else:
    print(".. PORT not set (local run)")

  print(">>> [PREFLIGHT] Done.")
  return 0

if __name__ == "__main__":
  raise SystemExit(main())
