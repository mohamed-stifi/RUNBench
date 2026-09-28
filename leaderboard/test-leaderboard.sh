#!/bin/sh
# test-leaderboard.sh — acceptance for Issue #11 (leaderboard + filters).
# Builds a sample runlog via replay runner (docker-free), one live oracle
# trial when the daemon is reachable, then checks splits, CI/sigma, infinity
# MTTR, cost columns, filters, append-only history, and releases.
set -u
PASS=0; FAIL=0; SKIP=0
ok() { PASS=$((PASS+1)); echo "ok: $1"; }
bad() { FAIL=$((FAIL+1)); echo "FAIL: $1"; }
skip() { SKIP=$((SKIP+1)); echo "skip: $1"; }
TMP="$(mktemp -d "${TMPDIR:-/tmp}/runbench-board.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT INT TERM
export RUNLOG="$TMP/runlog.jsonl"
PY=".venv/bin/python"; [ -x "$PY" ] || PY="python3"

echo "--- sample records via runner ---"
sh runner/run.sh run.dag-failure.001 null 7 3 >/dev/null 2>&1
sh runner/run.sh run.dag-failure.001 oracle 7 1 >/dev/null 2>&1
RUN_TIMEOUT_S=300 sh runner/run.sh run.dag-failure.001 oracle 7 1 --live >/dev/null 2>&1 \
  && LIVE_OK=1 || LIVE_OK=0
[ "$LIVE_OK" = 1 ] && ok "sample records generated (incl. live pass)" || skip "live pass sample (no daemon); replay-only board"
"$PY" leaderboard/build.py "$RUNLOG" "$TMP/board.json" --md "$TMP/LEADERBOARD.md" >/dev/null 2>&1 \
  && ok "board builds (schema-validated entries)" || bad "board builds (schema-validated entries)"

echo "--- splits + CI/sigma + infinity ---"
null_split="$("$PY" -c "import json;[print(e['split']) for e in json.load(open('$TMP/board.json'))['entries'] if e['agent']=='null']")"
[ "$null_split" = "multiple" ] && ok "null x3 lands in Multiple Trials" || bad "null x3 lands in Multiple Trials"
"$PY" - "$TMP/board.json" <<'EOF' 2>/dev/null && ok "CI/sigma/infinity/cost correct" || bad "CI/sigma/infinity/cost correct"
import json, sys
es = {e["agent"]: e for e in json.load(open(sys.argv[1]))["entries"]}
null, oracle = es["null"], es["oracle"]
assert null["mttr_unresolved"] and null["mttr_s_mean"] is None, null
assert null["ci95"] is not None and null["sigma"] is not None, null
assert oracle["split"] == "single" and oracle["ci95"] is None, oracle
assert null["cost"]["wallclock_s_mean"] is not None, null  # runner journal wall time
assert null["abstain_rate"] == 1.0 and oracle["evidence_score"] == 1.0, (null, oracle)
EOF
grep -q "∞" "$TMP/LEADERBOARD.md" && grep -q "## Multiple Trials" "$TMP/LEADERBOARD.md" \
  && ok "both splits render, unresolved MTTR as infinity" || bad "both splits render, unresolved MTTR as infinity"

echo "--- filters (DoD dimensions) ---"
"$PY" leaderboard/query.py "$TMP/board.json" --agent null | grep -q "1 of .* match" \
  && ok "filter by agent" || bad "filter by agent"
"$PY" leaderboard/query.py "$TMP/board.json" --split multiple --mode replay | grep -q "match" \
  && ok "filter by split+mode" || bad "filter by split+mode"
"$PY" leaderboard/query.py "$TMP/board.json" --scenario run.dag-failure.001 --class job-dag-failure-diagnosis --complexity medium --layer 4 | grep -q "match" \
  && ok "filter by scenario/class/complexity/layer" || bad "filter by scenario/class/complexity/layer"
if [ "$LIVE_OK" = 1 ]; then
  "$PY" leaderboard/query.py "$TMP/board.json" --min-resolved 100 | grep -q "1 of .* match" \
    && ok "metric filter min-resolved (live pass)" || bad "metric filter min-resolved (live pass)"
else
  skip "metric filter min-resolved (needs live pass)"
fi

echo "--- append-only history + release ---"
ids_before="$("$PY" -c "import json;print(sorted(sum([e['run_ids'] for e in json.load(open('$TMP/board.json'))['entries']],[])))")"
sh runner/run.sh run.dag-failure.001 null 7 1 >/dev/null 2>&1
"$PY" leaderboard/build.py "$RUNLOG" "$TMP/board.json" >/dev/null 2>&1
ids_after="$("$PY" -c "import json;print(sorted(sum([e['run_ids'] for e in json.load(open('$TMP/board.json'))['entries']],[])))")"
"$PY" - "$ids_before" "$ids_after" <<'EOF' 2>/dev/null && ok "rebuild preserves history (append-only)" || bad "rebuild preserves history (append-only)"
import ast, sys
before, after = ast.literal_eval(sys.argv[1]), ast.literal_eval(sys.argv[2])
assert set(before) <= set(after) and len(after) == len(before) + 1, (before, after)
EOF
sh leaderboard/release.sh "$TMP/board.json" v1-sample "$TMP/releases" >/dev/null 2>&1 \
  && ok "release manifest written" || bad "release manifest written"
"$PY" - "$TMP/releases/v1-sample.json" "$TMP/board.json" <<'EOF' 2>/dev/null && ok "release pins board sha + scenario tags" || bad "release pins board sha + scenario tags"
import hashlib, json, sys
man, raw = json.load(open(sys.argv[1])), open(sys.argv[2], "rb").read()
assert man["board_sha256"] == hashlib.sha256(raw).hexdigest(), man
assert "run.dag-failure.001@0.1.0" in man["scenario_tags"], man
assert man["release_tag"] == "dataset@v1-sample", man
EOF

echo "BOARD-TESTS $((PASS+FAIL)) run, $FAIL failed, $SKIP skipped"
[ "$FAIL" -eq 0 ] || exit 1
