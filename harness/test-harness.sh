#!/bin/sh
# test-harness.sh — acceptance tests for Issue #06 (POSIX sh + grep only).
# Usage: sh harness/test-harness.sh   (run from repo root)
# 1. Null-agent runs against sample scenario input -> valid result.json, exit 0.
# 2. Invalid output (missing evidence_refs/abstained/abstain_reason) fails
#    harness-side validation with clear field errors.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PY="$ROOT/.venv/bin/python"
[ -x "$PY" ] || PY="python3"
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "ok: $1"; }
bad() { FAIL=$((FAIL+1)); echo "NOT OK: $1"; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT INT TERM

echo "--- null-agent ---"
if sh harness/null-agent/run.sh harness/fixtures/scenario-data.sample.json "$TMP/result.json"; then
  ok "null-agent exits 0 on sample input"
else
  bad "null-agent exits 0 on sample input"
fi
[ -f "$TMP/result.json" ] && ok "result.json emitted" || bad "result.json emitted"
if grep -q '"abstained": true' "$TMP/result.json" && grep -q '"abstain_reason": "[^"]' "$TMP/result.json"; then
  ok "result abstains with reason"
else
  bad "result abstains with reason"
fi
if "$PY" harness/validate.py "$TMP/result.json" | grep -q "HARNESS-VALID"; then
  ok "null-agent output passes harness validation"
else
  bad "null-agent output passes harness validation"
fi

echo "--- invalid output ---"
out="$("$PY" harness/validate.py harness/fixtures/result-invalid.json 2>&1)"
code=$?
[ "$code" -ne 0 ] && ok "invalid output fails validation" || bad "invalid output fails validation"
for f in evidence_refs abstained abstain_reason; do
  case "$out" in *"$f"*) ok "error names missing field '$f'";; *) bad "error names missing field '$f'";; esac
done

total=$((PASS+FAIL)); echo "HARNESS-TESTS $PASS/$total passed"
[ "$FAIL" -eq 0 ]
