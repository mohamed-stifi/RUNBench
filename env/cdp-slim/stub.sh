#!/bin/sh
# Stub service entrypoint (Issue #04). POSIX sh, busybox only.
# Env: SERVICE_NAME (required), PORT (default 8080), SEED (default 7).
set -u

SERVICE_NAME="${SERVICE_NAME:?SERVICE_NAME required}"
PORT="${PORT:-8080}"
SEED="${SEED:-7}"

mkdir -p /var/www/state
printf 'ok %s seed=%s\n' "$SERVICE_NAME" "$SEED" > /var/www/health

# Initial (pre-fault) state per service. fault-inject.sh flips these.
case "$SERVICE_NAME" in
  airflow)
    printf 'success' > /var/www/state/dag.state
    printf 'sales_daily' > /var/www/state/dag.id
    ;;
  spark)
    printf 'running' > /var/www/state/app.state
    printf '8g' > /var/www/state/app.executor.memory
    ;;
  *)
    printf 'up' > /var/www/state/status
    ;;
esac

echo "stub $SERVICE_NAME listening on $PORT (seed=$SEED)"
exec darkhttpd /var/www --port "$PORT" --no-server-id
