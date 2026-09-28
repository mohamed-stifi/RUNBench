#!/bin/sh
# budget-hog — budget-breach fixture: declares huge token use, then lingers
# (Issue #10). The runner kill-switch must kill it mid-run and record
# budget_breach. Usage: run.sh [IN [OUT_DIR]]; sidecar OUT_DIR/run-meta.json.
set -u
OUT="${2:-/out/result.json}"
OUTD="$(dirname "$OUT")"
mkdir -p "$OUTD"
cat > "$OUT" <<EOF
{"contract_version": "1.0", "diagnosis": "", "actions": [], "evidence_refs": [], "abstained": true, "abstain_reason": "hog: testing budget kill-switch"}
EOF
printf '{"tokens": 999999, "turns": 99, "cost_suh": 99.9}\n' > "$OUTD/run-meta.json"
sleep 60
