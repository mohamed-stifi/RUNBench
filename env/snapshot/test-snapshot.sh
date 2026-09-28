#!/bin/sh
# test-snapshot.sh — acceptance for Issue #13 (snapshot & replay capture).
# Fully offline: builds snapshots via capture.sh --from-state (no docker),
# replays the null-agent 3x, requires diff-clean outputs + identical verdicts.
set -u
PASS=0; FAIL=0
ok() { PASS=$((PASS+1)); echo "ok: $1"; }
bad() { FAIL=$((FAIL+1)); echo "FAIL: $1"; }
TMP="$(mktemp -d "${TMPDIR:-/tmp}/runbench-snaptest.XXXXXX")"
trap 'chmod -R u+w "$TMP" 2>/dev/null; rm -rf "$TMP"' EXIT INT TERM
PY=".venv/bin/python"; [ -x "$PY" ] || PY="python3"

echo "--- capture (offline) ---"
mkdir -p "$TMP/state"
printf 'failed' > "$TMP/state/dag.state"
printf 'spark_submit_agg (mapped to application_1690000007_0001)' > "$TMP/state/task.state"
printf 'application_1690000007_0001' > "$TMP/state/app.id"
printf '2g' > "$TMP/state/app.executor.memory"
printf 'killed (ExecutorLostFailure: OOM)' > "$TMP/state/app.state"
printf 'ExecutorLostFailure (executor OOM, container killed by YARN for exceeding memory limits)' > "$TMP/state/app.log.sales_daily_agg_20260927"
sh env/snapshot/capture.sh --from-state "$TMP/state" run.dag-failure.001 7 "$TMP/snaps" >/dev/null 2>&1 \
  && ok "offline capture succeeds" || bad "offline capture succeeds"
SNAP="$TMP/snaps/run.dag-failure.001/snap-seed7"
for f in manifest.json scenario.slice.yaml alerts.json events.json logs-tail.txt metrics.json lineage.slice.yaml topology.json state/dag.state state/app.id; do
  [ -f "$SNAP/$f" ] || bad "snapshot contains $f"
done
[ -f "$SNAP/state/app.id" ] && ok "snapshot contains frozen states" || true
grep -q '"scenario_tag": "0.1.0"' "$SNAP/manifest.json" \
  && ok "snapshot versioned alongside scenario_tag" || bad "snapshot versioned alongside scenario_tag"
if touch "$SNAP/state/probe" 2>/dev/null; then bad "snapshot is read-only"; else ok "snapshot is read-only"; fi
sh env/snapshot/capture.sh --from-state "$TMP/state" run.dag-failure.001 7 "$TMP/snaps2" >/dev/null 2>&1
if diff -r -x manifest.json "$SNAP" "$TMP/snaps2/run.dag-failure.001/snap-seed7" >/dev/null 2>&1; then
  ok "re-capture deterministic (modulo captured_at)"
else
  bad "re-capture deterministic (modulo captured_at)"
fi

echo "--- replay determinism (3 runs, zero live containers) ---"
if grep -v '^[[:space:]]*#' env/snapshot/replay.sh | grep -E -q 'docker|compose|curl|wget'; then
  bad "replay.sh uses zero live services (no docker/curl)"
else
  ok "replay.sh uses zero live services (no docker/curl)"
fi
for i in 1 2 3; do
  sh env/snapshot/replay.sh "$SNAP" harness/null-agent/run.sh "$TMP/replay-$i" >/dev/null 2>&1 \
    || bad "replay run $i succeeds"
done
[ -f "$TMP/replay-3/result.json" ] && ok "3 replay runs succeed" || true
if diff -q "$TMP/replay-1/result.json" "$TMP/replay-2/result.json" >/dev/null 2>&1 \
&& diff -q "$TMP/replay-1/result.json" "$TMP/replay-3/result.json" >/dev/null 2>&1; then
  ok "3 replay outputs diff-clean"
else
  bad "3 replay outputs diff-clean"
fi
"$PY" harness/validate.py "$TMP/replay-1/result.json" >/dev/null 2>&1 \
  && ok "replay output validates harness-side" || bad "replay output validates harness-side"
sh evaluator/evaluate.sh scenarios/run.dag-failure.001.yaml "$TMP/replay-1/result.json" "$SNAP/state" "$TMP/verdict-1.json" 4 >/dev/null 2>&1
sh evaluator/evaluate.sh scenarios/run.dag-failure.001.yaml "$TMP/replay-3/result.json" "$SNAP/state" "$TMP/verdict-3.json" 4 >/dev/null 2>&1
if diff -q "$TMP/verdict-1.json" "$TMP/verdict-3.json" >/dev/null 2>&1 \
&& grep -q '"abstained": true' "$TMP/verdict-1.json"; then
  ok "replay verdicts identical (null-agent abstains)"
else
  bad "replay verdicts identical (null-agent abstains)"
fi
if docker info >/dev/null 2>&1; then
  if [ -z "$(docker compose -f env/cdp-slim/docker-compose.yml ps -q 2>/dev/null)" ]; then
    ok "zero live scenario containers during replay"
  else
    bad "zero live scenario containers during replay"
  fi
else
  ok "zero live scenario containers during replay (no daemon; script is docker-free)"
fi

echo "SNAPSHOT-TESTS $((PASS+FAIL)) run, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
