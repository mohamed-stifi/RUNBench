#!/bin/sh
# conformance.sh — harness conformance suite, evaluator-side stage (Issue #17).
# Usage: conformance.sh SCENARIO_YAML AGENT_RESULT_JSON
# The agent NEVER sees ground truth: it only ever received scenario_data.json.
# This script runs where the evaluator lives: it stages the agent output
# read-only (evaluator mounts agent output :ro in containers), validates it,
# rejects path traversal, and cross-checks evidence_refs against the scenario's
# ground_truth root_causes. Forged pass claims with bogus evidence score FAIL.
# Exit 0 CONFORMANCE-PASS, 1 CONFORMANCE-FAIL + reason. Green is required
# before an agent is listed on the board.
set -u
SCN="${1:?usage: conformance.sh SCENARIO_YAML AGENT_RESULT_JSON}"
RES="${2:?usage: conformance.sh SCENARIO_YAML AGENT_RESULT_JSON}"
HERE="$(dirname "$0")"
ROOT="$(cd "$HERE/.." && pwd)"
PY="$ROOT/.venv/bin/python"
[ -x "$PY" ] || PY="python3"

cfail() { echo "CONFORMANCE-FAIL: $1"; exit 1; }

[ -f "$SCN" ] || cfail "scenario not found: $SCN"
[ -f "$RES" ] || cfail "agent result not found: $RES"

# 1. Stage read-only (mirrors the :ro mount the evaluator container gets).
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT INT TERM
cp "$RES" "$STAGE/result.json"
chmod -w "$STAGE/result.json"
[ -w "$STAGE/result.json" ] && cfail "staging is writable (isolation broken)"

# 2. Harness-side validation on the staged (read-only) copy.
"$PY" "$ROOT/harness/validate.py" "$STAGE/result.json" >/dev/null 2>&1 \
  || cfail "output failed harness validation"

# 3. Path-traversal rejection: no '..' segments or absolute paths in output values.
grep -E -q '\.\.' "$STAGE/result.json" && cfail "path traversal in output (..)"
grep -E -q ':[[:space:]]*/' "$STAGE/result.json" && cfail "absolute path in output"

# 4. Abstain path: empty evidence is legitimate, skip the evidence check.
if grep -E -q '"abstained"[[:space:]]*:[[:space:]]*true' "$STAGE/result.json"; then
  echo "CONFORMANCE-PASS (abstain)"
  exit 0
fi

# 5. Evidence check: every ref must be <entity>:<probe> with entity in ground_truth root_causes.
CAUSES="$(awk '/^[[:space:]]*root_causes:/{cap=1; next} cap && /^[[:space:]]*- /{sub(/^[[:space:]]*-[[:space:]]*/, ""); print; next} cap{exit}' "$SCN")"
[ -n "$CAUSES" ] || cfail "scenario has no ground_truth root_causes"
REFS="$(grep -E -o '"[A-Za-z0-9][A-Za-z0-9._/-]*:[A-Za-z0-9][A-Za-z0-9._/-]*"' "$STAGE/result.json")"
[ -n "$REFS" ] || cfail "non-abstained result cites no evidence (entity:probe refs required)"
bad=""
for r in $REFS; do
  ent="$(printf '%s' "$r" | tr -d '"' | cut -d: -f1)"
  hit=0
  for c in $CAUSES; do [ "$ent" = "$c" ] && hit=1 && break; done
  [ "$hit" = 1 ] || bad="$bad $ent"
done
[ -z "$bad" ] || cfail "forged evidence (unknown entities:$bad) — scores fail"

echo "CONFORMANCE-PASS"
