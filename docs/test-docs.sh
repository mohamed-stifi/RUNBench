#!/bin/sh
# test-docs.sh — acceptance for Issue #16 (docs mirror behavior).
# Fails when: index links are dead, add-scenario.md references missing files,
# the coverage matrix drifts from scenarios/*.yaml, or a docs page is orphaned.
set -u
PASS=0; FAIL=0
ok() { PASS=$((PASS+1)); echo "ok: $1"; }
bad() { FAIL=$((FAIL+1)); echo "FAIL: $1"; }
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

links="$(grep -oE '\]\([^)]+\)' "$ROOT/docs/index.md" | sed 's/^](//;s/)$//' | grep -v '^http')"
dead=0
for l in $links; do
  case "$l" in \#*) continue;; esac
  [ -e "$ROOT/docs/$l" ] || { echo "dead index link: $l"; dead=1; }
done
[ "$dead" -eq 0 ] && ok "index links resolve" || bad "index links resolve"

refs="$(grep -oE '(docs|scenarios)/[A-Za-z0-9_./-]+' "$ROOT/docs/add-scenario.md")"
missing=0
for r in $refs; do
  [ -e "$ROOT/$r" ] || { echo "add-scenario references missing: $r"; missing=1; }
done
[ -e "$ROOT/scenarios/_template/scenario.yaml" ] || { echo "template scenario.yaml missing"; missing=1; }
[ "$missing" -eq 0 ] && ok "guide references exist (incl. template starter)" || bad "guide references exist (incl. template starter)"

drift=0
for f in "$ROOT"/scenarios/*.yaml; do
  id="$(grep -E '^id:' "$f" | head -1 | awk '{print $2}')"
  grep -q "$id" "$ROOT/docs/coverage.md" || { echo "coverage matrix missing: $id"; drift=1; }
done
[ "$drift" -eq 0 ] && ok "coverage matrix tracks every scenario" || bad "coverage matrix tracks every scenario"

orphan=0
for f in "$ROOT"/docs/*.md; do
  n="$(basename "$f")"
  [ "$n" = "index.md" ] && continue
  grep -q "$n" "$ROOT/docs/index.md" || { echo "orphaned docs page: $n"; orphan=1; }
done
[ "$orphan" -eq 0 ] && ok "no orphaned docs pages" || bad "no orphaned docs pages"

echo "DOCS-TESTS $((PASS+FAIL)) run, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
