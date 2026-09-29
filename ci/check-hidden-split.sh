#!/bin/sh
# check-hidden-split.sh — SWE-bench-Pro contamination lesson (Issue #15).
# The hidden split stays private: (a) no tracked hidden/ dir; (b) no public
# image build ever COPYs oracle material (solution/tests/state). Usage: check-hidden-split.sh [ROOT]
set -u
ROOT="${1:-.}"
FAIL=0
if git -C "$ROOT" ls-files hidden/ 2>/dev/null | grep -q .; then
  echo "GATE-FAIL: hidden split files tracked in git (hidden/ must stay private)" >&2
  git -C "$ROOT" ls-files hidden/ >&2
  FAIL=1
fi
found="$(find "$ROOT" -name Dockerfile -not -path "*/.git/*" -exec grep -lE "COPY.*(solution|tests|state)" {} + 2>/dev/null || true)"
if [ -n "$found" ]; then
  echo "GATE-FAIL: public image COPYs oracle material:" >&2
  echo "$found" >&2
  FAIL=1
fi
[ "$FAIL" -eq 0 ] && echo "HIDDEN-SPLIT-OK"
exit "$FAIL"
