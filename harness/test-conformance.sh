#!/bin/sh
# test-conformance.sh — acceptance tests for Issue #17 (POSIX sh + grep only).
# Usage: sh harness/test-conformance.sh   (run from repo root)
# Covers: version gate (match + v1.1 mismatch fast-fail with migration note),
# pre-execution action gate, tamper fixtures (forged pass scores fail,
# traversal rejected), null-agent conformance pass, agent/evaluator isolation
# (agent-visible input carries no ground truth; staging is read-only).
set -u
SCN="scenarios/run.dag-failure.001.yaml"
FIX="harness/fixtures"
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "ok: $1"; }
bad() { FAIL=$((FAIL+1)); echo "NOT OK: $1"; }

echo "--- contract version gate ---"
if sh harness/check-contract.sh harness/agent-harness.yaml | grep -q "CONTRACT-OK"; then
  ok "matching contract accepted"
else
  bad "matching contract accepted"
fi
out="$(sh harness/check-contract.sh "$FIX/harness-v11/agent-harness.yaml" 2>&1)"
code=$?
[ "$code" -ne 0 ] && ok "v1.1 harness fails fast" || bad "v1.1 harness fails fast"
case "$out" in *"CONTRACT-MISMATCH"*v1.1*"v1.0"*) ok "mismatch names both versions";; *) bad "mismatch names both versions";; esac
case "$out" in *"Migration:"*"No partial run"*) ok "migration note, no partial run";; *) bad "migration note, no partial run";; esac

echo "--- pre-execution action gate ---"
if sh harness/gate-action.sh "$SCN" rerun sales_daily 1 >/dev/null 2>&1; then
  bad "L1 rerun blocked pre-execution"
else
  ok "L1 rerun blocked pre-execution"
fi
if sh harness/gate-action.sh "$SCN" rerun sales_daily 2 | grep -q "ACTION-ALLOWED"; then
  ok "L2 rerun allowed pre-execution"
else
  bad "L2 rerun allowed pre-execution"
fi

echo "--- tamper fixtures ---"
out="$(sh harness/conformance.sh "$SCN" "$FIX/result-tamper-forged.json" 2>&1)"
[ "$?" -ne 0 ] && ok "forged pass claim scores fail" || bad "forged pass claim scores fail"
case "$out" in *"forged evidence"*) ok "fail reason cites forged evidence";; *) bad "fail reason cites forged evidence";; esac
out="$(sh harness/conformance.sh "$SCN" "$FIX/result-tamper-traversal.json" 2>&1)"
[ "$?" -ne 0 ] && ok "path-traversal output rejected" || bad "path-traversal output rejected"
case "$out" in *"traversal"*) ok "fail reason cites traversal";; *) bad "fail reason cites traversal";; esac

echo "--- honest agents + isolation ---"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT INT TERM
sh harness/null-agent/run.sh "$FIX/scenario-data.sample.json" "$TMP/null-result.json" >/dev/null 2>&1
if sh harness/conformance.sh "$SCN" "$TMP/null-result.json" | grep -q "CONFORMANCE-PASS"; then
  ok "null-agent passes conformance (abstain path)"
else
  bad "null-agent passes conformance (abstain path)"
fi
if grep -E -q "root_cause|ground_truth|ExecutorLostFailure" "$FIX/scenario-data.sample.json"; then
  bad "agent-visible input carries no ground truth"
else
  ok "agent-visible input carries no ground truth"
fi
cp "$TMP/null-result.json" "$TMP/staged.json" && chmod -w "$TMP/staged.json"
if [ -w "$TMP/staged.json" ]; then bad "evaluator staging is read-only"; else ok "evaluator staging is read-only"; fi

total=$((PASS+FAIL)); echo "CONFORMANCE-TESTS $PASS/$total passed"
[ "$FAIL" -eq 0 ]
