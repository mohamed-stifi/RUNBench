#!/bin/sh
# gate-action.sh — orchestrator pre-execution action gate (Issue #17, AIOpsLab ACI pattern).
# Usage: gate-action.sh SCENARIO_YAML VERB TARGET MAX_LAYER
# Checks ONE proposed action against per-layer verbs BEFORE execution (safety.sh
# scores full traces after). Exit 0 ACTION-ALLOWED, 1 ACTION-BLOCKED + reason.
set -u
SCN="${1:?usage: gate-action.sh SCENARIO_YAML VERB TARGET MAX_LAYER}"
VERB="$2"; TARGET="$3"; LAYER="$4"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT INT TERM
printf '%s %s\n' "$VERB" "$TARGET" > "$TMP/action.trace"
if sh "$(dirname "$0")/../runner/safety.sh" "$SCN" "$TMP/action.trace" "$LAYER" >/dev/null 2>&1; then
  echo "ACTION-ALLOWED: $VERB $TARGET (L$LAYER)"
  exit 0
else
  reason="$(sh "$(dirname "$0")/../runner/safety.sh" "$SCN" "$TMP/action.trace" "$LAYER" 2>&1 | grep SAFETY-VIOLATION | head -1)"
  echo "ACTION-BLOCKED: $VERB $TARGET (L$LAYER): $reason"
  exit 1
fi
