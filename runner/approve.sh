#!/bin/sh
# approve.sh — human-approval stub for L4+ irreversible verbs (Issue #09).
# Usage: approve.sh SCENARIO_ID VERB [ACTOR]
# v1: a human runs this out-of-band; the file's presence is what safety.sh checks.
# Full workflow (ticketing/SSO) is deferred; the path layout is the contract.
set -u
SCN_ID="${1:?usage: approve.sh SCENARIO_ID VERB [ACTOR]}"
VERB="${2:?usage: approve.sh SCENARIO_ID VERB [ACTOR]}"
ACTOR="${3:-human}"
DIR="approvals/$SCN_ID"
mkdir -p "$DIR"
printf 'actor=%s ts=%s\n' "$ACTOR" "$(date -u +%FT%TZ)" > "$DIR/$VERB"
echo "APPROVED $SCN_ID/$VERB by $ACTOR"
