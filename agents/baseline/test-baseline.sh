#!/bin/sh
# test-baseline.sh — acceptance for Issue #14 (baseline reference agent).
# Fully offline: snapshot from checked-in seed-state, baseline runs against it,
# verdict must land strictly between null-agent and oracle.
set -u
PASS=0; FAIL=0
ok() { PASS=$((PASS+1)); echo "ok: $1"; }
bad() { FAIL=$((FAIL+1)); echo "FAIL: $1"; }
TMP="$(mktemp -d "${TMPDIR:-/tmp}/runbench-basetest.XXXXXX")"
trap 'chmod -R u+w "$TMP" 2>/dev/null; rm -rf "$TMP"' EXIT INT TERM
PY=".venv/bin/python"; [ -x "$PY" ] || PY="python3"

echo "--- tools: timeout + truncation + read-only ---"
if grep -v '^[[:space:]]*#' agents/baseline/tools/obs.sh | grep -q 'curl' \
&& ! grep -v '^[[:space:]]*#' agents/baseline/tools/obs.sh | grep 'curl' | grep -q -v '\-m'; then
  ok "every tool call has a timeout"
else
  bad "every tool call has a timeout"
fi
if grep -v '^[[:space:]]*#' agents/baseline/tools/obs.sh agents/baseline/run.sh | grep -E -q 'curl .*(-X| --data)|PUT|POST|DELETE|docker |kubectl |rm -rf />?var|> /var/www/state'; then
  bad "tools are read-only (no writes/gated verbs)"
else
  ok "tools are read-only (no writes/gated verbs)"
fi
if seq 1 200 | sh agents/baseline/tools/summarize.sh 5 1000 | tail -1 | grep -q 'truncated'; then
  ok "summarizer truncates with marker"
else
  bad "summarizer truncates with marker"
fi
if ! sh agents/baseline/tools/obs.sh bogus >/dev/null 2>&1; then
  ok "unknown source exits non-zero"
else
  bad "unknown source exits non-zero"
fi

echo "--- baseline end-to-end via harness ---"
sh env/snapshot/capture.sh --from-state env/snapshot/seed-states/run.dag-failure.001-seed7 \
  run.dag-failure.001 7 "$TMP/snaps" >/dev/null 2>&1
SNAP="$TMP/snaps/run.dag-failure.001/snap-seed7"
SNAPSHOT_DIR="$SNAP" sh agents/baseline/run.sh harness/fixtures/scenario-data.sample.json "$TMP/result.json" >/dev/null 2>&1 \
  && ok "baseline runs end-to-end" || bad "baseline runs end-to-end"
"$PY" harness/validate.py "$TMP/result.json" >/dev/null 2>&1 \
  && ok "baseline output validates harness-side" || bad "baseline output validates harness-side"
sh evaluator/evaluate.sh scenarios/run.dag-failure.001.yaml "$TMP/result.json" "$SNAP/state" "$TMP/v-base.json" 4 >/dev/null 2>&1
sh evaluator/evaluate.sh scenarios/run.dag-failure.001.yaml evaluator/fixtures/agent-abstain.json "$SNAP/state" "$TMP/v-null.json" 4 >/dev/null 2>&1
sh evaluator/evaluate.sh scenarios/run.dag-failure.001.yaml evaluator/fixtures/agent-pass.json evaluator/fixtures/state-fixed "$TMP/v-oracle.json" 4 >/dev/null 2>&1
loc() { grep -E -o '"localization_score": [0-9.]+' "$1" | head -1 | sed 's/.* //'; }
pass() { grep -E -o '"pass_at_1": (true|false)' "$1" | head -1 | sed 's/.* //'; }
diag() { grep -E -o '"diagnosis_pass": (true|false)' "$1" | head -1 | sed 's/.* //'; }
mit() { grep -E -o '"mitigation_pass": (true|false)' "$1" | head -1 | sed 's/.* //'; }
[ "$(diag "$TMP/v-base.json")" = true ] && [ "$(mit "$TMP/v-base.json")" = false ] \
  && ok "baseline: diagnosis passes, mitigation fails (the split)" \
  || bad "baseline: diagnosis passes, mitigation fails (the split)"
nb="$(loc "$TMP/v-null.json")"; bb="$(loc "$TMP/v-base.json")"; ob="$(loc "$TMP/v-oracle.json")"
if awk "BEGIN{exit !(($nb < $bb) && (\"$(pass "$TMP/v-base.json")\" == \"false\") && (\"$(pass "$TMP/v-oracle.json")\" == \"true\"))}"; then
  ok "null($nb) < baseline($bb=$ob) < oracle(pass) ordering"
else
  bad "null($nb) < baseline($bb=$ob) < oracle(pass) ordering"
fi
grep -q 'spark.config.spark.executor.memory:probe_diagnosis_exact' "$TMP/result.json" \
  && ok "diagnosis is evidence-linked" || bad "diagnosis is evidence-linked"

echo "BASELINE-TESTS $((PASS+FAIL)) run, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
