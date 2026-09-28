#!/bin/sh
# run.sh — null-agent fixture: always abstains with reason (Issue #06).
# Usage: run.sh [INPUT_JSON [OUTPUT_JSON]] (defaults: /in/scenario_data.json /out/result.json)
# Pipeline-testing baseline: reads the goal for context, emits a valid
# abstained result.json, validates it harness-side, exits 0.
set -u
IN="${1:-/in/scenario_data.json}"
OUT="${2:-/out/result.json}"
HERE="$(dirname "$0")"
ROOT="$(cd "$HERE/../.." && pwd)"
PY="$ROOT/.venv/bin/python"
[ -x "$PY" ] || PY="python3"

goal="$(grep -E '"goal_template"' "$IN" | head -1 | sed -E 's/.*"[g]oal_template"[[:space:]]*:[[:space:]]*"//; s/".*//')"
[ -n "$goal" ] || goal="no goal provided"

mkdir -p "$(dirname "$OUT")"
cat > "$OUT" <<EOF
{
  "contract_version": "1.0",
  "diagnosis": "",
  "actions": [],
  "evidence_refs": [],
  "abstained": true,
  "abstain_reason": "null-agent: insufficient evidence to diagnose safely (goal: $goal)"
}
EOF
exec "$PY" "$ROOT/harness/validate.py" "$OUT"
