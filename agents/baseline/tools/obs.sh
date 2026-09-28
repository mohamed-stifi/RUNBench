#!/bin/sh
# obs.sh — unified read-only observation CLI for run.dag-failure.001 (Issue #14).
# One helper API/CLI behind sources (BrowserGym observation/action precedent;
# tools-not-raw-CLI principle): the agent never curls services directly.
#   obs.sh airflow [task.state|dag.state]   — Airflow task/DAG state
#   obs.sh spark   [app.state|app.executor.memory|app.id|app.log.<key>]
#   obs.sh logs    [app key, default sales_daily_agg_20260927] — Spark app log tail
#   obs.sh metrics                           — fault-signature metrics window
#   obs.sh lineage                           — lineage slice (chain direction)
# World resolution: $SNAPSHOT_DIR (replay/snapshot world) wins; else live stub
# endpoints ($OBS_AIRFLOW_URL/$OBS_SPARK_URL, default localhost:18081/18082).
# Read-only: only GETs local state files / HTTP GETs — no writes, no gated
# verbs (see specs/03-autonomy-layers.md). Every source has a timeout
# (curl -m 5; file reads are local) and streams through summarize.sh
# (timeout + truncation policy documented in docs/baseline.md).
set -u
HERE="$(dirname "$0")"
SRC="${1:?usage: obs.sh SOURCE [key] where SOURCE is airflow, spark, logs, metrics or lineage}"
KEY="${2:-}"
TIMEOUT=5

fetch_all() {
if [ -n "${SNAPSHOT_DIR:-}" ] && [ -d "${SNAPSHOT_DIR:-}" ]; then
  rd() { # rd <relpath> — read from snapshot world, empty on missing
    if [ -f "$SNAPSHOT_DIR/$1" ]; then cat "$SNAPSHOT_DIR/$1"; else printf '(no snapshot data: %s)\n' "$1"; fi
  }
  case "$SRC" in
    airflow) [ -n "$KEY" ] || KEY="dag.state"; rd "state/$KEY";;
    spark)   [ -n "$KEY" ] || KEY="app.state"; rd "state/$KEY";;
    logs)    [ -n "$KEY" ] || KEY="sales_daily_agg_20260927"; rd "state/app.log.$KEY";;
    metrics) rd "metrics.json";;
    lineage) if [ -f "$SNAPSHOT_DIR/lineage.slice.yaml" ]; then cat "$SNAPSHOT_DIR/lineage.slice.yaml"; else rd "scenario.slice.yaml"; fi;;
    *) echo "obs.sh: unknown source '$SRC'" >&2; exit 2;;
  esac
else
  AIRFLOW="${OBS_AIRFLOW_URL:-http://localhost:18081}"
  SPARK="${OBS_SPARK_URL:-http://localhost:18082}"
  fetch() { curl -fs -m "$TIMEOUT" "$1" 2>/dev/null || printf '(unavailable: %s)\n' "$1"; }
  case "$SRC" in
    airflow) [ -n "$KEY" ] || KEY="dag.state"; fetch "$AIRFLOW/state/$KEY";;
    spark)   [ -n "$KEY" ] || KEY="app.state"; fetch "$SPARK/state/$KEY";;
    logs)    [ -n "$KEY" ] || KEY="sales_daily_agg_20260927"; fetch "$SPARK/state/app.log.$KEY";;
    metrics) printf '{"spark.executor.memory": "%s", "spark.app.state": "%s"}\n' \
               "$(fetch "$SPARK/state/app.executor.memory")" "$(fetch "$SPARK/state/app.state")";;
    lineage) printf 'config -> app -> task -> dagrun (downstream failure order; see scenario spec)\n';;
    *) echo "obs.sh: unknown source '$SRC'" >&2; exit 2;;
  esac
  fi
}
# No pipe (it would mask exit codes): dispatch to tmp, then summarize.
OUT_TMP="$(mktemp "${TMPDIR:-/tmp}/runbench-obs.XXXXXX")"
trap 'rm -f "$OUT_TMP"' EXIT INT TERM
fetch_all > "$OUT_TMP"; rc=$?
[ "$rc" -ne 0 ] && exit "$rc"
sh "$HERE/summarize.sh" < "$OUT_TMP"
