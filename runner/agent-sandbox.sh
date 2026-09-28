#!/bin/sh
# agent-sandbox.sh — run an agent command egress-denied (Issue #09).
# Usage: agent-sandbox.sh IMAGE [CMD...]
# Container gets --network none + --cap-drop ALL; stdout/stderr is piped
# through redact.sh so leaked secrets never reach stored logs raw.
# Exit code is the agent command's own (callers decide pass/fail).
set -u
IMAGE="${1:?usage: agent-sandbox.sh IMAGE [CMD...]}"
shift
OUT="$(mktemp)"
docker run --rm --network none --cap-drop=ALL "$IMAGE" "$@" >"$OUT" 2>&1
code=$?
sh "$(dirname "$0")/redact.sh" "$OUT"
rm -f "$OUT"
exit $code
