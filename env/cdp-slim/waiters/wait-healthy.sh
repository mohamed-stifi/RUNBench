#!/bin/sh
# Wait until all cdp-slim services report healthy (Issue #04). POSIX sh + curl.
# Usage: wait-healthy.sh [timeout_s]; exit 0 when all healthy, 1 on timeout.
set -u

TIMEOUT="${1:-120}"
elapsed=0

# port:name pairs must match docker-compose.yml (env-overridable host ports).
SERVICES="${AIRFLOW_PORT:-18081}:airflow ${SPARK_PORT:-18082}:spark ${HIVE_PORT:-18083}:hive-metastore ${IMPALA_PORT:-18084}:impala ${OZONE_PORT:-18085}:ozone ${RANGER_PORT:-18086}:ranger ${YARN_PORT:-18087}:yarn"

while [ "$elapsed" -lt "$TIMEOUT" ]; do
  all_ok=1
  for pair in $SERVICES; do
    port="${pair%%:*}"
    name="${pair##*:}"
    body="$(curl -fs "http://localhost:${port}/health" 2>/dev/null || true)"
    case "$body" in
      "ok ${name} seed="*) ;;
      *)
        all_ok=0
        break
        ;;
    esac
  done
  if [ "$all_ok" -eq 1 ]; then
    echo "WAITERS-OK (all 7 services healthy after ${elapsed}s)"
    exit 0
  fi
  sleep 2
  elapsed=$((elapsed + 2))
done

echo "WAITERS-FAIL (timeout ${TIMEOUT}s waiting for healthy services)"
exit 1
