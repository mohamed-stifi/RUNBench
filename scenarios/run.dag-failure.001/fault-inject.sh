#!/bin/sh
# Fault injection for run.dag-failure.001 (Issue #04).
# Seeds the deterministic pre-fix failure: Spark executor OOM (memory 2g) ->
# Airflow task spark_submit_agg failed -> DAG run failed.
# Same SEED reproduces the same failure signature (app id derived from seed).
# Usage: fault-inject.sh [seed]   (default: $SEED or 7)
set -u

SEED="${1:-${SEED:-7}}"
AIRFLOW_PORT="${AIRFLOW_PORT:-18081}"
SPARK_PORT="${SPARK_PORT:-18082}"
COMPOSE="docker compose -f env/cdp-slim/docker-compose.yml"

# Deterministic app id from seed: application_<epoch+seed>_0001
APP_ID="application_$((1690000000 + SEED))_0001"
APP_KEY="sales_daily_agg_20260927"

echo "FAULT-INJECT run.dag-failure.001 (seed=$SEED)"

# Spark: executor OOM — memory too low, app killed
$COMPOSE exec -T spark sh -c "printf '2g' > /var/www/state/app.executor.memory"
$COMPOSE exec -T spark sh -c "printf 'killed (ExecutorLostFailure: OOM)' > /var/www/state/app.state"
$COMPOSE exec -T spark sh -c "printf '$APP_ID' > /var/www/state/app.id"
$COMPOSE exec -T spark sh -c "printf 'ExecutorLostFailure (executor OOM, container killed by YARN for exceeding memory limits)' > '/var/www/state/app.log.$APP_KEY'"

# Airflow: task failed -> DAG run failed
$COMPOSE exec -T airflow sh -c "printf 'failed' > /var/www/state/dag.state"
$COMPOSE exec -T airflow sh -c "printf 'spark_submit_agg (mapped to $APP_ID)' > /var/www/state/task.state"

echo "--- failure signature (seed=$SEED) ---"
echo "app.id:        $(curl -fs http://localhost:${SPARK_PORT}/state/app.id)"
echo "app.memory:    $(curl -fs http://localhost:${SPARK_PORT}/state/app.executor.memory)"
echo "app.state:     $(curl -fs http://localhost:${SPARK_PORT}/state/app.state)"
echo "task.state:    $(curl -fs http://localhost:${AIRFLOW_PORT}/state/task.state)"
echo "dag.state:     $(curl -fs http://localhost:${AIRFLOW_PORT}/state/dag.state)"
echo "FAULT-INJECTED"
