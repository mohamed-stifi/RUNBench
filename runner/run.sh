#!/bin/sh
# run.sh — Runner MVP: select -> provision -> inject -> run -> evaluate -> record
# (Issue #10). Multi-scenario MVP (run.dag-failure.001|.002), replay or live.
#   sh runner/run.sh SCENARIO AGENT [SEED] [TRIALS] [--live]
#   AGENT: null | baseline | oracle. SEED default 7, TRIALS default 1.
#   Replay (default): offline snapshot per trial, zero live containers.
#   --live: compose up + wait + fault-inject per trial, teardown after.
# Budgets/kill-switch (env knobs): RUN_TIMEOUT_S (default 120), RUN_MAX_TOKENS,
# RUN_MAX_TURNS, RUN_MAX_COST_SUH (unset = uncapped). Breach or deadline kills
# the agent (kill -9, portable — no GNU timeout needed) and records it.
# The evaluator always runs outside the agent container. Records append as
# immutable JSON lines to runs/runlog.jsonl (RUNLOG overrides), each embedding
# its reproducibility journal (config re-derivable from the record alone).
# Ref: specs/02-architecture.md (flow), specs/08-leaderboard.md (records).
set -u
SCN="${1:?usage: runner/run.sh SCENARIO AGENT [SEED] [TRIALS] [--live]}"
AGENT_NAME="${2:?usage: runner/run.sh SCENARIO AGENT [SEED] [TRIALS] [--live]}"
SEED="${3:-7}"
TRIALS="${4:-1}"
MODE="replay"
[ "${5:-}" = "--live" ] && MODE="live"
HERE="$(dirname "$0")"
ROOT="$(cd "$HERE/.." && pwd)"
RUNLOG="${RUNLOG:-$ROOT/runs/runlog.jsonl}"
TIMEOUT_S="${RUN_TIMEOUT_S:-120}"

case "$AGENT_NAME" in
  null) AGENT_SH="$ROOT/harness/null-agent/run.sh";;
  baseline) AGENT_SH="$ROOT/agents/baseline/run.sh";;
  oracle) AGENT_SH="$ROOT/agents/oracle/run.sh";;
  */*) case "$AGENT_NAME" in /*) AGENT_SH="$AGENT_NAME";; *) AGENT_SH="$ROOT/$AGENT_NAME";; esac;; # fixture path
  *) echo "RUNNER-ERROR: unknown AGENT $AGENT_NAME (null|baseline|oracle|path)" >&2; exit 2;;
esac

# Helpers (defined before use; POSIX sh executes top-down).
over() { # set BREACH if agent sidecar meta exceeds caps (else BREACH="")
  _f="$OUTD/run-meta.json"; BREACH=""
  _v() { sed -n -E "s/.*\"$1\"[[:space:]]*:[[:space:]]*([0-9]+(\.[0-9]+)?).*/\1/p" "$_f" | head -1; }
  [ -n "${RUN_MAX_TOKENS:-}" ] && [ -n "$(_v tokens)" ] && [ "$(_v tokens)" -gt "$RUN_MAX_TOKENS" ] 2>/dev/null && BREACH="tokens $(_v tokens) > $RUN_MAX_TOKENS"
  [ -z "$BREACH" ] && [ -n "${RUN_MAX_TURNS:-}" ] && [ -n "$(_v turns)" ] && [ "$(_v turns)" -gt "$RUN_MAX_TURNS" ] 2>/dev/null && BREACH="turns $(_v turns) > $RUN_MAX_TURNS"
  [ -z "$BREACH" ] && [ -n "${RUN_MAX_COST_SUH:-}" ] && [ -n "$(_v cost_suh)" ] \
    && awk "BEGIN{exit !(($(_v cost_suh)) > ($RUN_MAX_COST_SUH))}" 2>/dev/null && BREACH="cost_suh $(_v cost_suh) > $RUN_MAX_COST_SUH"
  return 0
}
meta_num() { [ -f "$OUTD/run-meta.json" ] && sed -n -E "s/.*\"$1\"[[:space:]]*:[[:space:]]*([0-9]+(\.[0-9]+)?).*/\1/p" "$OUTD/run-meta.json" | head -1 || true; }
jbool() { grep -E -o "\"$1\": (true|false)" "$VERDICT" | head -1 | sed 's/.* //'; }
jnum() { grep -E -o "\"$1\": (null|[0-9.]+)" "$VERDICT" | head -1 | sed 's/.* //'; }

# --- select: id+tag validate, oracle template + guardrail verbs required ---
echo "RUNNER-SELECT $SCN (tag+template+guardrails)"
"$ROOT/.venv/bin/python" "$ROOT/schemas/validate.py" "$ROOT/scenarios/$SCN.yaml" >/dev/null 2>&1 \
  || { echo "RUNNER-ERROR: scenario validation failed" >&2; exit 2; }
[ -f "$ROOT/scenarios/$SCN/solution.sh" ] && [ -f "$ROOT/scenarios/$SCN/test.sh" ] \
  || { echo "RUNNER-ERROR: oracle template missing (solution.sh/test.sh)" >&2; exit 2; }
grep -q '^[[:space:]]*safety:' "$ROOT/scenarios/$SCN.yaml" \
  || { echo "RUNNER-ERROR: guardrail verbs missing (safety block)" >&2; exit 2; }
SCN_TAG="$(grep -E '^[[:space:]]*version:' "$ROOT/scenarios/$SCN.yaml" | head -1 | sed -E 's/.*version:[[:space:]]*//; s/["'\'']//g')"
AGENT_VER="$AGENT_NAME@$(cd "$ROOT" && git rev-parse --short HEAD 2>/dev/null || echo novcs)"
RUN_ID="run-$(date +%s)-$$"
mkdir -p "$(dirname "$RUNLOG")" "$ROOT/runs"

pass_n=0; loc_sum="0"; mttr_sum=0; mttr_n=0
t=0
while [ "$t" -lt "$TRIALS" ]; do
  t=$((t+1))
  echo "RUNNER-TRIAL $t/$TRIALS (mode=$MODE seed=$SEED)"
  TDIR="$(mktemp -d "${TMPDIR:-/tmp}/runbench-trial.XXXXXX")"
  START="$(date +%s)"

  # --- provision + inject ---
  if [ "$MODE" = "live" ]; then
    (cd "$ROOT" && SEED="$SEED" docker compose -f env/cdp-slim/docker-compose.yml up --build -d) >/dev/null 2>&1
    sh "$ROOT/env/cdp-slim/waiters/wait-healthy.sh" 120 >/dev/null 2>&1
    SEED="$SEED" sh "$ROOT/scenarios/$SCN/fault-inject.sh" "$SEED" >/dev/null 2>&1
    DIGEST="$(docker inspect --format='{{.Id}}' runbench/cdp-slim-stub:0.1.0 2>/dev/null | tr -d '\n' || echo 'runbench/cdp-slim-stub:0.1.0 (unresolved)')"
    [ -n "$DIGEST" ] || DIGEST="runbench/cdp-slim-stub:0.1.0 (unresolved)"
    export LIVE_FIX=1
  else
    sh "$ROOT/env/snapshot/capture.sh" --from-state "$ROOT/env/snapshot/seed-states/$SCN-seed$SEED" \
      "$SCN" "$SEED" "$TDIR/snaps" >/dev/null 2>&1
    DIGEST="snapshot:$SCN/snap-seed$SEED"
    export LIVE_FIX=0
    export SNAPSHOT_DIR="$TDIR/snaps/$SCN/snap-seed$SEED"
  fi
  T_FAULT="$(date +%s)"

  # --- run harness with deadline + budget kill-switch (portable, no timeout(1)) ---
  IN="$TDIR/scenario_data.json"
  OUTD="$TDIR/out"; mkdir -p "$OUTD"
  cat > "$IN" <<EOF
{"contract_version": "1.0", "scenario_id": "$SCN", "goal_template": "Identify the root cause of the failed DAG run", "vars": {"dag_id": "sales_daily", "task_id": "spark_submit_agg"}, "autonomy_max": 4, "budget": {"time_min": 60, "steps": 50}}
EOF
  STATUS="fail"; NOTE="agent completed without verdict"; BREACH=""
  sh "$AGENT_SH" "$IN" "$OUTD/result.json" > "$TDIR/agent.log" 2>&1 &
  APID=$!
  DEADLINE=$((T_FAULT + TIMEOUT_S))
  while kill -0 "$APID" 2>/dev/null; do
    NOW="$(date +%s)"
    # budget kill-switch: agent sidecar run-meta.json checked mid-run
    if [ -f "$OUTD/run-meta.json" ]; then over; fi
    if [ -n "${BREACH:-}" ]; then
      kill -9 "$APID" 2>/dev/null; wait "$APID" 2>/dev/null
      STATUS="budget_breach"; NOTE="budget breach: $BREACH"; break
    fi
    if [ "$NOW" -ge "$DEADLINE" ]; then
      kill -9 "$APID" 2>/dev/null; wait "$APID" 2>/dev/null
      STATUS="timeout"; NOTE="deadline ${TIMEOUT_S}s exceeded (kill -9)"; break
    fi
    sleep 1
  done
  wait "$APID" 2>/dev/null
  T_DIAG="$(date +%s)"
  if [ -f "$OUTD/run-meta.json" ]; then over breach_reason; [ -n "${BREACH:-}" ] && { STATUS="budget_breach"; NOTE="budget breach: $BREACH"; }; fi

  # --- evaluate outside the agent container ---
  if [ "$MODE" = "live" ]; then
    sh "$ROOT/env/snapshot/capture.sh" "$SCN" "$SEED" "$TDIR/post" >/dev/null 2>&1
    STATEDIR="$TDIR/post/$SCN/snap-seed$SEED/state"
    (cd "$ROOT" && docker compose -f env/cdp-slim/docker-compose.yml down -v) >/dev/null 2>&1 || true
  else
    STATEDIR="$SNAPSHOT_DIR/state"
  fi
  T_MIT="$(date +%s)"
  TOK="$(meta_num tokens)"; TURNS="$(meta_num turns)"; SUH="$(meta_num cost_suh)"
  [ -n "$TOK" ] || TOK=null; [ -n "$TURNS" ] || TURNS=null; [ -n "$SUH" ] || SUH=null
  WALL=$((T_DIAG - T_FAULT))
  cat > "$TDIR/run-meta.json" <<EOF
{"t_fault": $T_FAULT, "t_diagnosed": $T_DIAG, "t_mitigated": $T_MIT, "tokens": $TOK, "turns": $TURNS, "cost_suh": $SUH, "query_runtime_s": $WALL}
EOF
  VERDICT="$TDIR/verdict.json"
  if [ "$STATUS" = "timeout" ] || [ "$STATUS" = "budget_breach" ] || [ ! -f "$OUTD/result.json" ]; then
    [ "$STATUS" = "fail" ] && { STATUS="fail"; NOTE="agent wrote no result.json"; }
    printf '{"scenario_id": "%s", "evaluator_version": "1.1", "diagnosis_pass": false, "mitigation_pass": false, "evidence_ok": false, "safety_violation": false, "abstained": false, "malformed": true, "pass_at_1": false, "localization_score": 0.00, "mttd_s": null, "mttr_s": null, "ttp_s": null, "cost": {"tokens": %s, "turns": %s, "cost_suh": %s, "query_runtime_s": %s}, "notes": ["runner: %s"]}\n' \
      "$SCN" "$TOK" "$TURNS" "$SUH" "$WALL" "$NOTE" > "$VERDICT"
  else
    sh "$ROOT/evaluator/evaluate.sh" "$ROOT/scenarios/$SCN.yaml" "$OUTD/result.json" "$STATEDIR" "$VERDICT" 4 "$TDIR/run-meta.json" >/dev/null 2>&1
  fi

  # --- record (immutable append; journal embedded) ---
  DP="$(jbool diagnosis_pass)"; MP="$(jbool mitigation_pass)"; P1="$(jbool pass_at_1)"; AB="$(jbool abstained)"
  LOC="$(jnum localization_score)"; MTTR="$(jnum mttr_s)"
  if [ "$STATUS" = "fail" ]; then
    if [ "$AB" = true ]; then STATUS="abstained"; NOTE="agent abstained";
    elif [ "$P1" = true ]; then STATUS="pass"; NOTE="pass@1";
    elif [ "$DP" = true ]; then STATUS="diagnosed"; NOTE="diagnosis only, no mitigation";
    else NOTE="completed, no pass"; fi
  fi
  [ "$P1" = true ] && pass_n=$((pass_n+1))
  loc_sum="$(awk "BEGIN{printf \"%.2f\", $loc_sum + $LOC}")"
  if [ "$MTTR" != "null" ] && [ "$P1" = true ]; then mttr_sum=$((mttr_sum + MTTR)); mttr_n=$((mttr_n+1)); fi
  END="$(date +%s)"
  printf '{"run_id": "%s", "date": "%s", "agent": "%s", "agent_version": "%s", "scenario_id": "%s", "scenario_tag": "%s", "seed": %s, "trial": %s, "mode": "%s", "status": "%s", "note": "%s", "verdict": %s, "journal": {"scenario_tag": "%s", "seed": %s, "image_digest": "%s", "mode": "%s", "agent_cmd": "%s", "timeout_s": %s, "budget": {"max_tokens": "%s", "max_turns": "%s", "max_cost_suh": "%s"}, "started_at": %s, "ended_at": %s}}\n' \
    "$RUN_ID" "$(date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date)" "$AGENT_NAME" "$AGENT_VER" \
    "$SCN" "$SCN_TAG" "$SEED" "$t" "$MODE" "$STATUS" "$NOTE" "$(cat "$VERDICT")" \
    "$SCN_TAG" "$SEED" "$DIGEST" "$MODE" "$AGENT_SH" "$TIMEOUT_S" \
    "${RUN_MAX_TOKENS:-uncapped}" "${RUN_MAX_TURNS:-uncapped}" "${RUN_MAX_COST_SUH:-uncapped}" \
    "$START" "$END" >> "$RUNLOG"
  unset SNAPSHOT_DIR LIVE_FIX BREACH
  chmod -R u+w "$TDIR" 2>/dev/null; rm -rf "$TDIR"
  echo "RUNNER-RECORDED $STATUS ($NOTE)"
done

# --- multi-trial summary (mean; CI lands in Issue #11) ---
mean_loc="$(awk "BEGIN{printf \"%.2f\", $loc_sum / $TRIALS}")"
if [ "$mttr_n" -gt 0 ]; then mean_mttr="$((mttr_sum / mttr_n))"; else mean_mttr="null"; fi
echo "RUNNER-SUMMARY trials=$TRIALS pass=$pass_n/$TRIALS mean_localization=$mean_loc mean_mttr_resolved_s=$mean_mttr runlog=$RUNLOG"
