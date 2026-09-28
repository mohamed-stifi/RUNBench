#!/bin/sh
# run.sh — baseline reference agent for run.dag-failure.001 (Issue #14).
# Uses only agents/baseline/tools/obs.sh (tools-not-raw-CLI) + summarize.sh.
# Pipeline: goal -> airflow/spark state -> logs/metrics/lineage -> heuristic
# diagnosis (executor-OOM signature) -> valid result.json. Read-only: observes,
# never fixes, so expected verdict is diagnosis-pass / mitigation-fail — the
# split that separates it from null-agent (abstain) and oracle (full pass).
# Usage: run.sh [INPUT_JSON [OUTPUT_JSON]] (defaults: /in/scenario_data.json /out/result.json)
set -u
IN="${1:-/in/scenario_data.json}"
OUT="${2:-/out/result.json}"
HERE="$(dirname "$0")"
ROOT="$(cd "$HERE/../.." && pwd)"
PY="$ROOT/.venv/bin/python"
[ -x "$PY" ] || PY="python3"
OBS="sh $HERE/tools/obs.sh"

# Replay/snapshot world auto-detect: cwd inside a snapshot copy.
if [ -z "${SNAPSHOT_DIR:-}" ] && [ -f "./state/dag.state" ]; then
  SNAPSHOT_DIR="$(pwd)"; export SNAPSHOT_DIR
fi

goal="$(grep -E '"goal_template"' "$IN" | head -1 | sed -E 's/.*"[g]oal_template"[[:space:]]*:[[:space:]]*"//; s/".*//')"
dag_id="$(grep -E '"dag_id"' "$IN" | head -1 | sed -E 's/.*"dag_id"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/')"
[ -n "$dag_id" ] || dag_id="sales_daily"

dag_state="$($OBS airflow dag.state)"
task_state="$($OBS airflow task.state)"
app_state="$($OBS spark app.state)"
app_mem="$($OBS spark app.executor.memory)"
app_log="$($OBS logs)"
# shellcheck disable=SC2086 — word-split intended for multi-line obs output
echo "$app_log" | grep -E -q 'OOM|ExecutorLostFailure|exceeding memory' && oom_sig=yes || oom_sig=no
echo "$dag_state" | grep -q 'failed' && dag_failed=yes || dag_failed=no

emit() { # emit <abstained> <diagnosis> <reason>
  mkdir -p "$(dirname "$OUT")"
  cat > "$OUT" <<EOF
{"contract_version": "1.0", "diagnosis": "$1", "actions": ["inspect $dag_id", "propose executor-memory increase then rerun $dag_id"], "evidence_refs": ["spark.config.spark.executor.memory:probe_diagnosis_exact"], "abstained": $2, "abstain_reason": "$3"}
EOF
  exec "$PY" "$ROOT/harness/validate.py" "$OUT"
}

if [ "$dag_failed" = yes ] && [ "$oom_sig" = yes ] && [ -n "$app_mem" ]; then
  emit "root cause is spark.config.spark.executor.memory set to $app_mem causing $app_state; task state $task_state, dag run $dag_state (goal: $goal)" false ""
else
  # Evidence inconclusive: abstain with reason instead of guessing.
  mkdir -p "$(dirname "$OUT")"
  cat > "$OUT" <<EOF
{"contract_version": "1.0", "diagnosis": "", "actions": [], "evidence_refs": [], "abstained": true, "abstain_reason": "baseline: dag_failed=$dag_failed oom_signature=$oom_sig memory='$app_mem' — inconclusive, abstaining"}
EOF
  exec "$PY" "$ROOT/harness/validate.py" "$OUT"
fi
