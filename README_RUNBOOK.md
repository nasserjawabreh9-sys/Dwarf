# Station Runbook (60s)

## Start
- Backend: `bash station_loop_backend.sh`
- Frontend: `cd frontend && npm run dev -- --host 127.0.0.1 --port 5173`
- Open UI: `termux-open-url "http://127.0.0.1:5173/#/settings"`

## Ops
- Edit Mode Key required for write ops.
- Test all: `bash scripts/ops/self_test.sh`

## Files
- Config: station_meta/bindings/uui_config.json
- Logs: station_meta/*
