#!/bin/sh
# test-runner.sh — acceptance for Issue #10 (runner MVP + budgets + journal).
# Replay tests are docker-free; live oracle/null runs execute only when the
# docker daemon is reachable (else skipped, clearly reported).
set -u
PASS=0; FAIL=0; SKIP=0
ok() { PASS=$((PASS+1)); echo "ok: $1"; }
bad() { FAIL=$((FAIL+1)); echo "FAIL: $1"; }
skip() { SKIP=$((SKIP+1)); echo "skip: $1"; }
TMP="$(mktemp -d "${TMPDIR:-/tmp}/runbench-runner.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT INT TERM
export RUNLOG="$TMP/runlog.jsonl"
PY=".venv/bin/python"; [ -x "$PY" ] || PY="python3"
last_status() { tail -1 "$RUNLOG" | "$PY" -c "import json,sys;print(json.load(sys.stdin)['status'])"; }

echo "--- replay: oracle + null records ---"
sh runner/run.sh run.dag-failure.001 oracle 7 1 >/dev/null 2>&1
[ "$(last_status)" = "diagnosed" ] && ok "oracle replay records diagnosis-only" || bad "oracle replay records diagnosis-only (got $(last_status))"
sh runner/run.sh run.dag-failure.001 null 7 1 >/dev/null 2>&1
[ "$(last_status)" = "abstained" ] && ok "null replay records abstain" || bad "null replay records abstain (got $(last_status))"
"$PY" - "$RUNLOG" <<'EOF' 2>/dev/null && ok "records carry version+tag+journal" || bad "records carry version+tag+journal"
import json, sys
recs = [json.loads(l) for l in open(sys.argv[1])]
assert len(recs) == 2, recs
for r in recs:
    assert r["agent_version"] and r["scenario_tag"] == "0.1.0" and r["seed"] == 7, r
    j = r["journal"]
    assert j["scenario_tag"] == r["scenario_tag"] and j["seed"] == r["seed"], j
    assert j["image_digest"] and j["timeout_s"] and j["started_at"] <= j["ended_at"], j
    assert "diagnosis_pass" in r["verdict"], r
EOF

echo "--- kill-switch: timeout + budget ---"
s0="$(date +%s)"
RUN_TIMEOUT_S=3 sh runner/run.sh run.dag-failure.001 runner/fixtures/agents/sleeper/run.sh 7 1 >/dev/null 2>&1
s1="$(date +%s)"
[ "$(last_status)" = "timeout" ] && ok "deadline kill records timeout" || bad "deadline kill records timeout (got $(last_status))"
[ $((s1 - s0)) -lt 25 ] && ok "timeout returns fast ($((s1-s0))s << sleep 120s)" || bad "timeout returns fast ($((s1-s0))s)"
b0="$(date +%s)"
RUN_MAX_TOKENS=100 sh runner/run.sh run.dag-failure.001 runner/fixtures/agents/budget-hog/run.sh 7 1 >/dev/null 2>&1
b1="$(date +%s)"
[ "$(last_status)" = "budget_breach" ] && ok "budget breach kills and records" || bad "budget breach kills and records (got $(last_status))"
[ $((b1 - b0)) -lt 30 ] && ok "breach kill is mid-run ($((b1-b0))s << linger 60s)" || bad "breach kill is mid-run ($((b1-b0))s)"

echo "--- immutability + multi-trial ---"
lines_before="$(wc -l < "$RUNLOG" | tr -d ' ')"
head_sum="$(head -2 "$RUNLOG" | cksum)"
sh runner/run.sh run.dag-failure.001 oracle 7 2 2>&1 | grep -q "pass=0/2 mean_localization=1.00" \
  && ok "multi-trial summary reports means" || bad "multi-trial summary reports means"
[ "$(head -2 "$RUNLOG" | cksum)" = "$head_sum" ] \
  && ok "records immutable (earlier lines untouched)" || bad "records immutable (earlier lines untouched)"
[ "$(wc -l < "$RUNLOG" | tr -d ' ')" = "$((lines_before + 2))" ] \
  && ok "one record per trial appended" || bad "one record per trial appended"
"$PY" - "$RUNLOG" <<'EOF' 2>/dev/null && ok "every record is single-line JSON (JSONL invariant)" || bad "every record is single-line JSON (JSONL invariant)"
import json, sys
for i, line in enumerate(open(sys.argv[1])):
    json.loads(line)
EOF

echo "--- live (needs daemon) ---"
if docker info >/dev/null 2>&1; then
  RUN_TIMEOUT_S=300 sh runner/run.sh run.dag-failure.001 oracle 7 1 --live >/dev/null 2>&1
  [ "$(last_status)" = "pass" ] && ok "live oracle run records pass" || bad "live oracle run records pass (got $(last_status))"
  RUN_TIMEOUT_S=300 sh runner/run.sh run.dag-failure.001 null 7 1 --live >/dev/null 2>&1
  [ "$(last_status)" = "abstained" ] && ok "live null run records abstain" || bad "live null run records abstain (got $(last_status))"
  docker compose -f env/cdp-slim/docker-compose.yml down -v >/dev/null 2>&1 || true
else
  skip "live oracle/null runs (no docker daemon)"
fi

echo "RUNNER-TESTS $((PASS+FAIL)) run, $FAIL failed, $SKIP skipped"
[ "$FAIL" -eq 0 ] || exit 1
