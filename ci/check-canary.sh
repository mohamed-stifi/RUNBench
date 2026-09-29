#!/bin/sh
# check-canary.sh — Big-Bench style contamination gate (Issue #15).
# Every scenario oracle script must carry the RUNBENCH-CANARY string so
# training crawls can exclude benchmark data. Usage: check-canary.sh [ROOT]
set -u
ROOT="${1:-.}"
CANARY="RUNBENCH-CANARY"
FAIL=0
check() {
  if ! grep -q "$CANARY" "$1"; then
    echo "GATE-FAIL: canary missing in $1" >&2
    FAIL=1
  fi
}
check "$ROOT/scenarios/_template/solution.sh"
check "$ROOT/scenarios/_template/test.sh"
check "$ROOT/scenarios/_template/lib/probes.sh"
for f in "$ROOT"/scenarios/*/solution.sh "$ROOT"/scenarios/*/test.sh "$ROOT"/scenarios/*/fault-inject.sh; do
  [ -e "$f" ] && check "$f"
done
[ "$FAIL" -eq 0 ] && echo "CANARY-OK"
exit "$FAIL"
