#!/bin/sh
# oracle-5x.sh — Terminal-Bench style flakiness gate (Issue #15).
# Runs solution.sh + test.sh 5x from a clean env each iteration; any failure
# blocks merge. Logs each iteration; failing iteration log path is printed.
# Docker-free: without a live stack the oracle falls back to seeded fixtures
# (deterministic). Usage: oracle-5x.sh SCENARIO_ID [SEED]
set -u
SCEN="${1:?usage: oracle-5x.sh SCENARIO_ID [SEED]}"
SEED="${2:-7}"
DIR="${SCEN_DIR:-scenarios/$SCEN}"
STATE_DIR="/tmp/runbench/$SCEN"
LOGDIR="/tmp/runbench/oracle-5x-$SCEN"
mkdir -p "$LOGDIR"
i=0
while [ "$i" -lt 5 ]; do
  i=$((i+1))
  rm -rf "$STATE_DIR"
  if sh "$DIR/solution.sh" >"$LOGDIR/run$i-solution.log" 2>&1 \
    && STATE_DIR="$STATE_DIR" SEED="$SEED" sh "$DIR/test.sh" >"$LOGDIR/run$i-test.log" 2>&1; then
    echo "oracle-5x [$SCEN] run $i/5: PASS"
  else
    echo "GATE-FAIL: oracle-5x [$SCEN] run $i/5 FAILED — see $LOGDIR/run$i-{solution,test}.log" >&2
    tail -5 "$LOGDIR/run$i-test.log" "$LOGDIR/run$i-solution.log" >&2
    exit 1
  fi
done
echo "ORACLE-5X-OK [$SCEN] 5/5 green (seed $SEED, clean env each run)"
