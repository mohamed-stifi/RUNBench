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
  for pat in "$@"; do
    grep -E -q "$pat" "$out" || { bad "$name (missing '$pat')"; return; }
  done
  ok "$name"
}

echo "--- golden fixtures ---"
expect_eval "oracle output passes" "$FIX/agent-pass.json" "$FIX/state-fixed" true \
  '"diagnosis_pass": true' '"mitigation_pass": true' '"evidence_ok": true' '"safety_violation": false'
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

echo "--- purity ---"
A="$TMP/purity-a.json"; B="$TMP/purity-b.json"
sh evaluator/evaluate.sh "$SCN" "$FIX/agent-pass.json" "$FIX/state-fixed" "$A" >/dev/null 2>&1
sh evaluator/evaluate.sh "$SCN" "$FIX/agent-pass.json" "$FIX/state-fixed" "$B" >/dev/null 2>&1
if [ "$(cat "$A")" = "$(cat "$B")" ]; then ok "pure function: identical verdicts"; else bad "pure function: identical verdicts"; fi

total=$((PASS+FAIL)); echo "EVALUATOR-TESTS $PASS/$total passed"
[ "$FAIL" -eq 0 ]
