#!/bin/sh
# test-all.sh — executable acceptance for Issue #12 (DoD2 auto-evaluability).
# Every scenario must: validate, go 5/5 oracle from a clean env, and score
# pass_at_1=true in the evaluator on its reference (oracle) output.
# Usage: test-all.sh [SCENARIO_ID...] (default: all scenarios/*.yaml)
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1
PY="$ROOT/.venv/bin/python"; [ -x "$PY" ] || PY="python3"
PASS=0; FAIL=0
ok() { PASS=$((PASS+1)); echo "ok: $1"; }
bad() { FAIL=$((FAIL+1)); echo "FAIL: $1"; }

IDS="${*:-}"
if [ -z "$IDS" ]; then
  IDS="$(for f in "$ROOT"/scenarios/*.yaml; do grep -E '^id:' "$f" | head -1 | awk '{print $2}'; done)"
fi
for id in $IDS; do
  yaml="$ROOT/scenarios/$id.yaml"
  if sh "$ROOT/bin/scenario" validate "$yaml" >/dev/null 2>&1; then ok "$id validates"; else bad "$id validates"; continue; fi
  seed="$(grep -E '^  seed:' "$yaml" | head -1 | awk '{print $2}')"
  if sh "$ROOT/ci/oracle-5x.sh" "$id" "$seed" >/dev/null 2>&1; then ok "$id oracle-5x"; else bad "$id oracle-5x"; continue; fi
  out="$("$PY" - "$ROOT/evaluator/evaluate.sh" "$yaml" "/tmp/runbench/$id/result.json" "/tmp/runbench/$id" "$ROOT" <<'EOF'
import json, subprocess, sys
ev, yaml, res, state, root = sys.argv[1:6]
outp = "/tmp/runbench-eval-check.json"
r = subprocess.run(["sh", ev, yaml, res, state, outp], capture_output=True, text=True)
v = json.load(open(outp))
print("pass" if v.get("pass_at_1") is True else f"NO: {v}")
EOF
)"
  if [ "$out" = "pass" ]; then ok "$id evaluator pass on reference"; else bad "$id evaluator pass on reference ($out)"; fi
done
echo "SCENARIO-TESTS $((PASS+FAIL)) run, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
