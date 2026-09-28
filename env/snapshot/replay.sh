#!/bin/sh
# replay.sh — deterministic diagnosis-only replay (Issue #13).
# Runs an agent entrypoint against a read-only snapshot copy with ZERO live
# containers: no docker, no compose, no network calls in this script.
# The agent sees the frozen snapshot as its world (cwd) plus a harness
# scenario_data.json input; it writes result.json outside the read-only tree.
# Usage: replay.sh SNAPSHOT_DIR AGENT_RUN_SH OUT_DIR [MAX_LAYER]
set -u
SNAP="${1:?usage: replay.sh SNAPSHOT_DIR AGENT_RUN_SH OUT_DIR [MAX_LAYER]}"
AGENT="${2:?usage: replay.sh SNAPSHOT_DIR AGENT_RUN_SH OUT_DIR [MAX_LAYER]}"
OUT="${3:?usage: replay.sh SNAPSHOT_DIR AGENT_RUN_SH OUT_DIR [MAX_LAYER]}"
LAYER="${4:-4}"

for f in manifest.json scenario.slice.yaml state/dag.state; do
  [ -f "$SNAP/$f" ] || { echo "REPLAY-ERROR: snapshot missing $f" >&2; exit 2; }
done
[ -x "$AGENT" ] || [ -f "$AGENT" ] || { echo "REPLAY-ERROR: agent not found: $AGENT" >&2; exit 2; }
case "$AGENT" in /*) ;; *) AGENT="$(pwd)/$AGENT";; esac
case "$OUT" in /*) ;; *) OUT="$(pwd)/$OUT";; esac

SCN_ID="$(sed -n -E 's/.*"scenario_id"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/p' "$SNAP/manifest.json" | head -1)"
SNAP_TAG="$(sed -n -E 's/.*"snapshot_tag"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/p' "$SNAP/manifest.json" | head -1)"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/runbench-replay.XXXXXX")"
trap 'chmod -R u+w "$WORK" 2>/dev/null; rm -rf "$WORK"' EXIT INT TERM
cp -R "$SNAP" "$WORK/world"
chmod -R a-w "$WORK/world"
mkdir -p "$OUT"

cat > "$WORK/scenario_data.json" <<EOF
{"contract_version": "1.0", "scenario_id": "$SCN_ID", "goal_template": "Identify the root cause of the failed DAG run with linked evidence and propose a safe rerun plan; abstain if evidence is inconclusive", "vars": {"dag_id": "sales_daily", "task_id": "spark_submit_agg", "snapshot_tag": "$SNAP_TAG", "replay_mode": true}, "autonomy_max": $LAYER, "budget": {"time_min": 60, "steps": 50}}
EOF

# Sandboxed shell: agent runs with cwd inside the read-only snapshot copy and
# can only write its result outside it. No services, no network, no docker.
(cd "$WORK/world" && sh "$AGENT" "$WORK/scenario_data.json" "$OUT/result.json") \
  || { echo "REPLAY-ERROR: agent entrypoint failed" >&2; exit 1; }
[ -f "$OUT/result.json" ] || { echo "REPLAY-ERROR: agent wrote no result.json" >&2; exit 1; }
echo "REPLAY-OK $OUT/result.json (snapshot $SNAP_TAG, zero live containers)"
