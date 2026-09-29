#!/bin/sh
# check-seed-pinning.sh — determinism gate (Issue #15).
# Every scenario must pin environment.seed (schema requires it too; this gate
# gives the clear per-file message). Usage: check-seed-pinning.sh [ROOT]
set -u
ROOT="${1:-.}"
FAIL=0
for f in "$ROOT"/scenarios/*.yaml; do
  [ -e "$f" ] || continue
  if ! grep -qE "^  seed: [0-9]+" "$f"; then
    echo "GATE-FAIL: seed not pinned in $f (add environment.seed)" >&2
    FAIL=1
  fi
done
[ "$FAIL" -eq 0 ] && echo "SEED-OK"
exit "$FAIL"
