#!/bin/sh
# capture.sh — snapshot & replay capture for run.dag-failure.001 (Issue #13).
# Freezes the post-fault observable state (alerts, events, logs tail, metrics
# window, lineage slice, topology) into a versioned, read-only snapshot dir
# that replay.sh can serve to an agent with zero live containers.
# Ref: specs/05-environment.md (ITBench-AA offline snapshot pattern).
#
# Live usage (after `make start-scenario SCENARIO=run.dag-failure.001`):
#   sh env/snapshot/capture.sh run.dag-failure.001 [SEED] [OUT_ROOT]
# Offline usage (no docker; for tests/CI):
#   sh env/snapshot/capture.sh --from-state STATE_DIR run.dag-failure.001 [SEED] [OUT_ROOT]
# Output: OUT_ROOT/<scenario>/snap-seed<SEED>/ (+ manifest.json)
# Only volatile field is manifest.captured_at (metadata, never a replay input).
set -u

FROM_STATE=""
if [ "${1:-}" = "--from-state" ]; then FROM_STATE="$2"; shift 2; fi
SCN="${1:?usage: capture.sh [--from-state STATE_DIR] SCENARIO [SEED] [OUT_ROOT]}"
SEED="${2:-7}"
OUT_ROOT="${3:-env/snapshots}"

if [ "$SCN" != "run.dag-failure.001" ]; then
  echo "SNAPSHOT-ERROR: v1 supports run.dag-failure.001 only" >&2; exit 2
fi

# POSIX-portable timestamp (busybox date has no -u +%FT...; keep it simple).
STAMP="$(date '+%Y-%m-%dT%H:%M:%S%z' 2>/dev/null || echo unknown)"
SNAP="$OUT_ROOT/$SCN/snap-seed$SEED"
rm -rf "$SNAP"
mkdir -p "$SNAP/state"

get() { # get <url> <dest> — curl, empty file on failure (never aborts capture)
  curl -fs -m 5 "$1" > "$2" 2>/dev/null || : > "$2"
}

if [ -n "$FROM_STATE" ]; then
  echo "SNAPSHOT-OFFLINE $SCN (seed=$SEED) from $FROM_STATE"
  for k in dag.state task.state app.id app.executor.memory app.state; do
    [ -f "$FROM_STATE/$k" ] && cp "$FROM_STATE/$k" "$SNAP/state/$k" || : > "$SNAP/state/$k"
  done
  ls "$FROM_STATE"/app.log.* 2>/dev/null | while read -r l; do cp "$l" "$SNAP/state/"; done
  for svc in airflow spark hive impala ozone ranger yarn; do
    printf '{"service":"%s","status":"unknown (offline capture)","snapshot_mode":true}\n' "$svc" > "$SNAP/$svc.health.json"
  done
  printf '(offline capture: no live container logs available)\n' > "$SNAP/logs-tail.txt"
else
  echo "SNAPSHOT-LIVE $SCN (seed=$SEED)"
  AIRFLOW_PORT="${AIRFLOW_PORT:-18081}"; SPARK_PORT="${SPARK_PORT:-18082}"
  HIVE_PORT="${HIVE_PORT:-18083}"; IMPALA_PORT="${IMPALA_PORT:-18084}"
  OZONE_PORT="${OZONE_PORT:-18085}"; RANGER_PORT="${RANGER_PORT:-18086}"
  YARN_PORT="${YARN_PORT:-18087}"
  get "http://localhost:${AIRFLOW_PORT}/health"             "$SNAP/airflow.health.json"
  get "http://localhost:${AIRFLOW_PORT}/state/task.state"   "$SNAP/state/task.state"
  get "http://localhost:${AIRFLOW_PORT}/state/dag.state"    "$SNAP/state/dag.state"
  get "http://localhost:${SPARK_PORT}/health"               "$SNAP/spark.health.json"
  get "http://localhost:${SPARK_PORT}/state/app.id"         "$SNAP/state/app.id"
  get "http://localhost:${SPARK_PORT}/state/app.executor.memory" "$SNAP/state/app.executor.memory"
  get "http://localhost:${SPARK_PORT}/state/app.state"      "$SNAP/state/app.state"
  get "http://localhost:${SPARK_PORT}/state/app.log.sales_daily_agg_20260927" "$SNAP/state/app.log.sales_daily_agg_20260927"
  get "http://localhost:${HIVE_PORT}/health"   "$SNAP/hive.health.json"
  get "http://localhost:${IMPALA_PORT}/health" "$SNAP/impala.health.json"
  get "http://localhost:${OZONE_PORT}/health"  "$SNAP/ozone.health.json"
  get "http://localhost:${RANGER_PORT}/health" "$SNAP/ranger.health.json"
  get "http://localhost:${YARN_PORT}/health"   "$SNAP/yarn.health.json"
  (docker compose -f env/cdp-slim/docker-compose.yml logs --tail=50 --no-log-prefix 2>/dev/null || echo "(compose logs unavailable)") > "$SNAP/logs-tail.txt"
fi

DAG_STATE="$(cat "$SNAP/state/dag.state" 2>/dev/null)"; [ -n "$DAG_STATE" ] || DAG_STATE="unknown"
APP_ID="$(cat "$SNAP/state/app.id" 2>/dev/null)";      [ -n "$APP_ID" ] || APP_ID="unknown"
APP_MEM="$(cat "$SNAP/state/app.executor.memory" 2>/dev/null)"; [ -n "$APP_MEM" ] || APP_MEM="unknown"
APP_STATE="$(cat "$SNAP/state/app.state" 2>/dev/null)"; [ -n "$APP_STATE" ] || APP_STATE="unknown"
TASK_STATE="$(cat "$SNAP/state/task.state" 2>/dev/null)"; [ -n "$TASK_STATE" ] || TASK_STATE="unknown"

# alerts/events/metrics/lineage/topology: frozen slices derived from the
# captured states + scenario spec (stub env exposes states, not streams).
cat > "$SNAP/alerts.json" <<EOF
[{"alert": "AirflowDagRunFailed", "dag_id": "sales_daily", "state": "$DAG_STATE", "seed": $SEED}]
EOF
cat > "$SNAP/events.json" <<EOF
[{"t": 0, "event": "fault_injected", "seed": $SEED, "app_id": "$APP_ID"},
 {"t": 1, "event": "spark_app_state", "state": "$APP_STATE", "executor_memory": "$APP_MEM"},
 {"t": 2, "event": "airflow_task_state", "task": "spark_submit_agg", "state": "$TASK_STATE"},
 {"t": 3, "event": "airflow_dagrun_state", "dag_id": "sales_daily", "state": "$DAG_STATE"}]
EOF
cat > "$SNAP/metrics.json" <<EOF
{"window": "fault_signature", "spark.executor.memory": "$APP_MEM", "spark.app.state": "$APP_STATE", "airflow.dag.state": "$DAG_STATE"}
EOF
cp "scenarios/$SCN.yaml" "$SNAP/scenario.slice.yaml" 2>/dev/null || cp "scenarios/$SCN.yml" "$SNAP/scenario.slice.yaml"
awk '/^[[:space:]]*lineage_edges:/{cap=1; print; next} cap && /^[[:space:]]*- /{print; next} cap{exit}' \
  "scenarios/$SCN.yaml" > "$SNAP/lineage.slice.yaml" 2>/dev/null || : > "$SNAP/lineage.slice.yaml"
cat > "$SNAP/topology.json" <<EOF
{"services": ["airflow", "spark", "hive", "impala", "ozone", "ranger", "yarn"], "dag": "sales_daily", "failed_task": "spark_submit_agg", "spark_app": "$APP_ID"}
EOF
SCN_TAG="$(grep -E '^[[:space:]]*version:' "scenarios/$SCN.yaml" 2>/dev/null | head -1 | sed -E 's/.*version:[[:space:]]*//; s/["'\'']//g')"
[ -n "$SCN_TAG" ] || SCN_TAG="unknown"
cat > "$SNAP/manifest.json" <<EOF
{"scenario_id": "$SCN", "scenario_tag": "$SCN_TAG", "seed": $SEED, "snapshot_tag": "snap-seed$SEED", "captured_at": "$STAMP", "mode": "$([ -n "$FROM_STATE" ] && echo offline || echo live)", "captured": ["alerts", "events", "logs_tail", "metrics_window", "lineage_slice", "topology", "state/dag.state", "state/task.state", "state/app.*"], "live_only": ["streaming logs/metrics", "container internals", "wall-clock timing", "interactive shells/queries"]}
EOF

chmod -R a-w "$SNAP"
echo "SNAPSHOT-OK $SNAP"
