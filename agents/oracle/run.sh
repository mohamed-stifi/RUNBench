#!/bin/sh
# run.sh — oracle reference agent for run.dag-failure.001 (Issue #10).
# Writes the known-good diagnosis with evidence links; applies ground-truth
# fix variant 1 (memory 2g→8g, task cleared, DAG rerun) ONLY when LIVE_FIX=1
# and a live scenario env is up (compose exec into stub state files).
# In replay/snapshot mode there is nothing to fix (read-only world), so the
# expected verdict there is diagnosis-pass / mitigation-fail; the full pass
# record requires --live. Usage: run.sh [INPUT_JSON [OUTPUT_JSON]]
set -u
IN="${1:-/in/scenario_data.json}"
OUT="${2:-/out/result.json}"
HERE="$(dirname "$0")"
ROOT="$(cd "$HERE/../.." && pwd)"
PY="$ROOT/.venv/bin/python"
[ -x "$PY" ] || PY="python3"

goal="$(grep -E '"goal_template"' "$IN" | head -1 | sed -E 's/.*"[g]oal_template"[[:space:]]*:[[:space:]]*"//; s/".*//')"
[ -n "$goal" ] || goal="no goal provided"

if [ "${LIVE_FIX:-0}" = "1" ]; then
  COMPOSE="docker compose -f $ROOT/env/cdp-slim/docker-compose.yml"
  $COMPOSE exec -T spark sh -c "printf '8g' > /var/www/state/app.executor.memory" >/dev/null 2>&1
  $COMPOSE exec -T spark sh -c "printf 'running' > /var/www/state/app.state" >/dev/null 2>&1
  $COMPOSE exec -T airflow sh -c "printf 'success' > /var/www/state/dag.state" >/dev/null 2>&1
  $COMPOSE exec -T airflow sh -c "printf 'spark_submit_agg (cleared, rerun ok)' > /var/www/state/task.state" >/dev/null 2>&1
  echo "ORACLE-FIX applied (live env)" >&2
fi

mkdir -p "$(dirname "$OUT")"
cat > "$OUT" <<EOF
{"contract_version": "1.0", "diagnosis": "root cause is spark.config.spark.executor.memory set to 2g causing ExecutorLostFailure OOM (goal: $goal)", "actions": ["inspect sales_daily", "rerun sales_daily"], "evidence_refs": ["spark.config.spark.executor.memory:probe_diagnosis_exact"], "abstained": false, "abstain_reason": ""}
EOF
exec "$PY" "$ROOT/harness/validate.py" "$OUT"
