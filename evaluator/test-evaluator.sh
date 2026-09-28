#!/bin/sh
# test-evaluator.sh — golden-fixture tests for evaluator v1 (Issue #07).
# Usage: sh evaluator/test-evaluator.sh   (run from repo root)
# Each fixture asserts its expected verdict: pass, near-miss, abstain-scored,
# timeout (missing output), malformed output, tampered in-container output.
# The evaluator must be a pure function of (final-state + agent-output +
# ground truth): identical inputs re-evaluated give identical verdicts.
set -u
SCN="scenarios/run.dag-failure.001.yaml"
FIX="evaluator/fixtures"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PY="$ROOT/.venv/bin/python"
[ -x "$PY" ] || PY="python3"
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "ok: $1"; }
bad() { FAIL=$((FAIL+1)); echo "NOT OK: $1"; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT INT TERM

# expect_eval <name> <agent-json> <state-dir> <expected pass_at_1 true|false> [extra grep pattern...]
expect_eval() {
  name="$1"; agent="$2"; state="$3"; want="$4"; shift 4
  out="$TMP/$(echo "$name" | tr ' ' '_').json"
  if ! sh evaluator/evaluate.sh "$SCN" "$agent" "$state" "$out" >/dev/null 2>&1; then
    bad "$name (evaluator crashed)"; return
  fi
  [ -f "$out" ] || { bad "$name (no machine-readable JSON)"; return; }
  got="$(grep -E -o '"pass_at_1": (true|false)' "$out" | head -1 | sed 's/.* //')"
  [ "$got" = "$want" ] || { bad "$name (want pass_at_1=$want, got $got)"; return; }
  if ! "$PY" evaluator/validate-verdict.py "$out" >/dev/null 2>&1; then
    bad "$name (verdict fails verdict.schema.json)"; return
  fi
  for pat in "$@"; do
    grep -E -q "$pat" "$out" || { bad "$name (missing '$pat')"; return; }
  done
  ok "$name"
}

echo "--- golden fixtures ---"
expect_eval "oracle output passes" "$FIX/agent-pass.json" "$FIX/state-fixed" true \
  '"diagnosis_pass": true' '"mitigation_pass": true' '"evidence_ok": true' '"safety_violation": false' \
  '"localization_score": 1.00' '"mttd_s": null'
expect_eval "near-miss fails on diagnosis+evidence" "$FIX/agent-nearmiss.json" "$FIX/state-fixed" false \
  '"diagnosis_pass": false' '"mitigation_pass": true' '"evidence_ok": false'
expect_eval "abstain recorded, no crash" "$FIX/agent-abstain.json" "$FIX/state-faulted" false \
  '"abstained": true'
expect_eval "timeout (missing output) fails cleanly" "$TMP/does-not-exist.json" "$FIX/state-faulted" false \
  '"malformed": true'
expect_eval "malformed output fails cleanly" "$FIX/agent-malformed.json" "$FIX/state-faulted" false \
  '"malformed": true'
expect_eval "tampered in-container output ignored" "$FIX/agent-tampered.json" "$FIX/state-faulted-tampered" false \
  '"mitigation_pass": false' '"evidence_ok": false'

echo "--- partial credit + timers + cost ---"
expect_eval "wrong node same chain scores partial" "$FIX/agent-partial.json" "$FIX/state-fixed" false \
  '"diagnosis_pass": false' '"localization_score": 0.50'
exact="$(grep -E -o '"localization_score": [0-9.]+' "$TMP/oracle_output_passes.json" | head -1 | sed 's/.* //')"
partial="$(grep -E -o '"localization_score": [0-9.]+' "$TMP/wrong_node_same_chain_scores_partial.json" | head -1 | sed 's/.* //')"
unrelated="$(grep -E -o '"localization_score": [0-9.]+' "$TMP/near-miss_fails_on_diagnosis+evidence.json" | head -1 | sed 's/.* //')"
if [ -n "$exact" ] && [ -n "$partial" ] && [ -n "$unrelated" ] \
  && awk "BEGIN{exit !(($exact > $partial) && ($partial > $unrelated))}"; then
  ok "strict order exact($exact) > chain-node($partial) > unrelated($unrelated)"
else
  bad "strict order exact($exact) > chain-node($partial) > unrelated($unrelated)"
fi
MOUT="$TMP/with_meta.json"
sh evaluator/evaluate.sh "$SCN" "$FIX/agent-pass.json" "$FIX/state-fixed" "$MOUT" 4 "$FIX/run-meta.sample.json" >/dev/null 2>&1
meta_ok=1
for pat in '"mttd_s": 300' '"mttr_s": 900' '"ttp_s": 600' '"tokens": 12500' '"turns": 7' '"cost_suh": 2.5' '"query_runtime_s": 180'; do
  grep -E -q "$pat" "$MOUT" || meta_ok=0
done
[ "$meta_ok" = 1 ] && ok "run record carries timers+cost" || bad "run record carries timers+cost"
"$PY" evaluator/validate-verdict.py "$MOUT" >/dev/null 2>&1 && ok "meta verdict validates" || bad "meta verdict validates"

echo "--- purity ---"
A="$TMP/purity-a.json"; B="$TMP/purity-b.json"
sh evaluator/evaluate.sh "$SCN" "$FIX/agent-pass.json" "$FIX/state-fixed" "$A" >/dev/null 2>&1
sh evaluator/evaluate.sh "$SCN" "$FIX/agent-pass.json" "$FIX/state-fixed" "$B" >/dev/null 2>&1
if [ "$(cat "$A")" = "$(cat "$B")" ]; then ok "pure function: identical verdicts"; else bad "pure function: identical verdicts"; fi

total=$((PASS+FAIL)); echo "EVALUATOR-TESTS $PASS/$total passed"
[ "$FAIL" -eq 0 ]
