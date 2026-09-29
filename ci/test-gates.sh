#!/bin/sh
# test-gates.sh — acceptance for Issue #15 (CI gates).
# Every gate fails INDEPENDENTLY on a deliberately broken fixture (kept in
# TMPDIR, never committed) with a clear GATE-FAIL message, and passes on the
# real tree. Flaky-oracle failures block merge with logs attached.
set -u
PASS=0; FAIL=0
ok() { PASS=$((PASS+1)); echo "ok: $1"; }
bad() { FAIL=$((FAIL+1)); echo "FAIL: $1"; }
# expect_fail NAME GATE-FAIL-SUBSTRING -- CMD...
expect_fail() {
  name="$1"; want="$2"; shift 2
  [ "$1" = "--" ] && shift
  out="$("$@" 2>&1)"; code=$?
  if [ "$code" -ne 0 ] && echo "$out" | grep -q "$want"; then ok "$name"
  else bad "$name (exit=$code, want GATE-FAIL matching '$want')"; echo "$out" | head -3; fi
}
TMP="$(mktemp -d "${TMPDIR:-/tmp}/runbench-gates.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT INT TERM
PY=".venv/bin/python"; [ -x "$PY" ] || PY="python3"

echo "--- broken fixtures fail each gate independently ---"
# 1. scenario validation
grep -v '^id:' scenarios/run.dag-failure.001.yaml > "$TMP/broken.yaml"
expect_fail "validate rejects broken scenario" "scenario validate" -- sh bin/scenario validate "$TMP/broken.yaml"
# 2. flaky oracle (fails 3rd run) blocks merge with logs
mkdir -p "$TMP/flaky/x"
printf '#!/bin/sh\necho ok\n' > "$TMP/flaky/x/solution.sh"
printf '#!/bin/sh\nn=$(cat /tmp/runbench-flaky-count 2>/dev/null || echo 0); n=$((n+1)); echo "$n" > /tmp/runbench-flaky-count; [ "$n" -ne 3 ]\n' > "$TMP/flaky/x/test.sh"
chmod +x "$TMP/flaky/x/"*.sh
rm -f /tmp/runbench-flaky-count
expect_fail "oracle-5x blocks flaky oracle" "GATE-FAIL.*run 3/5" -- env SCEN_DIR="$TMP/flaky/x" sh ci/oracle-5x.sh x
[ -f "/tmp/runbench/oracle-5x-x/run3-test.log" ] && ok "failing iteration log attached" || bad "failing iteration log attached"
# 3a. release rewrite blocked
R="$TMP/repo"; mkdir -p "$R/leaderboard/releases"
git -C "$R" init -q 2>/dev/null; git -C "$R" config user.email t@t; git -C "$R" config user.name t
cp leaderboard/board.sample.json "$R/leaderboard/board.sample.json"
echo '{"v":1}' > "$R/leaderboard/releases/v1.json"
git -C "$R" add -A && git -C "$R" commit -qm base
echo '{"v":2}' > "$R/leaderboard/releases/v1.json"
git -C "$R" commit -qam rewrite
expect_fail "append-only rejects release rewrite" "GATE-FAIL" -- sh ci/check-append-only.sh HEAD~1 HEAD "$R"
# 3b. run_id deletion blocked, clean append passes
git -C "$R" checkout -qb t2 HEAD~1 2>/dev/null
"$PY" - "$R/leaderboard/board.sample.json" <<'EOF'
import json, sys
p = sys.argv[1]; b = json.load(open(p)); b["entries"][0]["run_ids"] = b["entries"][0]["run_ids"][1:]
json.dump(b, open(p, "w"), indent=2)
EOF
git -C "$R" commit -qam drop
expect_fail "append-only rejects run_id deletion" "GATE-FAIL" -- sh ci/check-append-only.sh HEAD~1 HEAD "$R"
# 4. fake secret fails the scan (random-looking: example keys are allowlisted)
mkdir -p "$TMP/leak"
echo "deploy_token = \"$("$PY" -c "import secrets; print('ghp_'+secrets.token_hex(18))")\"" > "$TMP/leak/deploy.sh"
expect_fail "secret scan catches fake key" "GATE-FAIL" -- sh ci/check-secrets.sh "$TMP/leak"
# 5. missing canary
mkdir -p "$TMP/nocan/scenarios/_template" "$TMP/nocan/scenarios/x"
for f in solution.sh test.sh; do grep -v CANARY "scenarios/run.dag-failure.001/$f" > "$TMP/nocan/scenarios/x/$f"; done
cp scenarios/_template/solution.sh scenarios/_template/test.sh "$TMP/nocan/scenarios/_template/"
cp scenarios/_template/lib "$TMP/nocan/scenarios/_template/" 2>/dev/null || mkdir -p "$TMP/nocan/scenarios/_template/lib"
grep -v CANARY scenarios/_template/lib/probes.sh > "$TMP/nocan/scenarios/_template/lib/probes.sh" 2>/dev/null || true
expect_fail "canary gate names offender" "GATE-FAIL.*canary missing" -- sh ci/check-canary.sh "$TMP/nocan"
# 6. unpinned seed
mkdir -p "$TMP/noseed/scenarios"; grep -v '^  seed:' scenarios/run.dag-failure.001.yaml > "$TMP/noseed/scenarios/x.yaml"
expect_fail "seed gate rejects unpinned scenario" "GATE-FAIL.*seed not pinned" -- sh ci/check-seed-pinning.sh "$TMP/noseed"
# 7a. tracked hidden split
H="$TMP/hid"; mkdir -p "$H/hidden"; git -C "$H" init -q 2>/dev/null; git -C "$H" config user.email t@t; git -C "$H" config user.name t
echo key > "$H/hidden/keys.txt"; git -C "$H" add -A && git -C "$H" commit -qm x
expect_fail "hidden-split gate rejects tracked hidden/" "GATE-FAIL.*hidden" -- sh ci/check-hidden-split.sh "$H"
# 7b. image COPYing oracle material
mkdir -p "$TMP/img"; printf 'FROM alpine\nCOPY solution/solve.sh /app/\n' > "$TMP/img/Dockerfile"
expect_fail "hidden-split gate rejects oracle COPY" "GATE-FAIL.*COPY" -- sh ci/check-hidden-split.sh "$TMP/img"
# 8. trials < 3
"$PY" - leaderboard/board.sample.json "$TMP/single-board.json" <<'EOF'
import json, sys
b = json.load(open(sys.argv[1])); b["entries"] = [e for e in b["entries"] if e["split"] == "single"] or [dict(b["entries"][0], split="single", trials=1)]
json.dump(b, open(sys.argv[2], "w"))
EOF
expect_fail "trials gate requires n>=3" "GATE-FAIL.*trials>=3" -- sh ci/check-trials.sh "$TMP/single-board.json"
# 9. quarantine blocks release, not merge
"$PY" - "$TMP/quar.json" <<'EOF'
import json, sys
json.dump({"quarantined": [{"scenario_id": "run.dag-failure.001", "reason": "fixture flake", "log": "ci-fixture"}]}, open(sys.argv[1], "w"))
EOF
out="$(QUARANTINE_JSON="$TMP/quar.json" sh leaderboard/release.sh leaderboard/board.sample.json blocked "$TMP/rel" 2>&1)"; code=$?
echo "$out" | grep -q "quarantined" && [ "$code" -ne 0 ] && ok "quarantine blocks release" || bad "quarantine blocks release"
export RUNLOG="$TMP/rl.jsonl"
sh runner/run.sh run.dag-failure.001 null 7 1 >/dev/null 2>&1
"$PY" leaderboard/build.py "$RUNLOG" "$TMP/rebuilt.json" >/dev/null 2>&1 \
  && ok "quarantine does not block board build (merge)" || bad "quarantine does not block board build (merge)"

echo "--- green main: all gates pass on the real tree ---"
sh bin/scenario validate scenarios/run.dag-failure.001.yaml >/dev/null 2>&1 && ok "validate green" || bad "validate green"
sh ci/oracle-5x.sh run.dag-failure.001 7 >/dev/null 2>&1 && ok "oracle-5x green" || bad "oracle-5x green"
sh ci/check-canary.sh >/dev/null 2>&1 && ok "canary green" || bad "canary green"
sh ci/check-seed-pinning.sh >/dev/null 2>&1 && ok "seed green" || bad "seed green"
sh ci/check-hidden-split.sh >/dev/null 2>&1 && ok "hidden-split green" || bad "hidden-split green"
sh ci/check-trials.sh leaderboard/board.sample.json >/dev/null 2>&1 && ok "trials green" || bad "trials green"
sh ci/check-secrets.sh . >/dev/null 2>&1 && ok "secrets green (gitleaks)" || bad "secrets green (gitleaks)"
sh ci/check-append-only.sh HEAD HEAD . >/dev/null 2>&1 && ok "append-only green (empty diff)" || bad "append-only green (empty diff)"
sh runner/test-safety.sh >/dev/null 2>&1 && ok "trace-redaction green" || bad "trace-redaction green"

echo "GATE-TESTS $((PASS+FAIL)) run, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
