#!/bin/sh
# check-append-only.sh — leaderboard history gate (Issue #15).
# Usage: check-append-only.sh BASE HEAD [ROOT]
# Fails when BASE..HEAD (a) modifies/deletes anything under
# leaderboard/releases/, or (b) drops run_ids from leaderboard/board.sample.json.
set -u
BASE="${1:?usage: check-append-only.sh BASE HEAD [ROOT]}"
HEAD="${2:?usage: check-append-only.sh BASE HEAD [ROOT]}"
ROOT="${3:-.}"
FAIL=0
changed="$(git -C "$ROOT" diff --name-only --diff-filter=MDR "$BASE" "$HEAD" -- leaderboard/releases/ || true)"
if [ -n "$changed" ]; then
  echo "GATE-FAIL: release history rewritten (releases/ are immutable, add new files only):" >&2
  echo "$changed" >&2
  FAIL=1
fi
if git -C "$ROOT" diff --name-only "$BASE" "$HEAD" -- leaderboard/board.sample.json | grep -q .; then
  PY=".venv/bin/python"; [ -x "$PY" ] || PY="python3"
  "$PY" - "$ROOT" "$BASE" "$HEAD" <<'EOF' || FAIL=1
import subprocess, json, sys
root, base, head = sys.argv[1], sys.argv[2], sys.argv[3]
def board(rev):
    try:
        raw = subprocess.run(["git", "-C", root, "show", f"{rev}:leaderboard/board.sample.json"],
                             capture_output=True, text=True, check=True).stdout
    except subprocess.CalledProcessError:
        return set()
    return {r for e in json.loads(raw)["entries"] for r in e["run_ids"]}
before, after = board(base), board(head)
missing = before - after
if missing:
    print(f"GATE-FAIL: board history lost {len(missing)} run_ids: {sorted(missing)[:3]}", file=sys.stderr)
    sys.exit(1)
EOF
fi
[ "$FAIL" -eq 0 ] && echo "APPEND-ONLY-OK"
exit "$FAIL"
