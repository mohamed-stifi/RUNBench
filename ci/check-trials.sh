#!/bin/sh
# check-trials.sh — n>=3 gate for new scenarios (Issue #15, paper section 4.4).
# Every scenario in scenarios/*.yaml needs a multiple-split board entry with
# >=3 trials in the sample board. Usage: check-trials.sh BOARD_JSON [ROOT]
set -u
BOARD="${1:?usage: check-trials.sh BOARD_JSON [ROOT]}"
ROOT="${2:-.}"
PY=".venv/bin/python"; [ -x "$PY" ] || PY="python3"
FAIL=0
for f in "$ROOT"/scenarios/*.yaml; do
  [ -e "$f" ] || continue
  id="$(grep -E '^id:' "$f" | head -1 | awk '{print $2}')"
  ok="$("$PY" - "$BOARD" "$id" <<'EOF'
import json, sys
board, sid = json.load(open(sys.argv[1])), sys.argv[2]
print("yes" if any(e["scenario_id"] == sid and e["split"] == "multiple" and e["trials"] >= 3 for e in board["entries"]) else "no")
EOF
)"
  if [ "$ok" != "yes" ]; then
    echo "GATE-FAIL: scenario $id lacks a multiple-split entry with trials>=3 in $BOARD" >&2
    FAIL=1
  fi
done
[ "$FAIL" -eq 0 ] && echo "TRIALS-OK"
exit "$FAIL"
