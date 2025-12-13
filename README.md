# Station - Global Scripts Pack

## One command ops
bash scripts/station_ops.sh status
bash scripts/station_ops.sh build
bash scripts/station_ops.sh run
bash scripts/station_ops.sh restart
bash scripts/station_ops.sh stop
bash scripts/station_ops.sh logs backend
bash scripts/station_ops.sh logs frontend
bash scripts/station_ops.sh doctor
bash scripts/station_ops.sh backup
bash scripts/station_ops.sh restore <backup.tgz>
bash scripts/station_ops.sh git init
bash scripts/station_ops.sh git push "message"

## Health
curl -fsS http://127.0.0.1:8000/healthz
