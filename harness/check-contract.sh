#!/bin/sh
# check-contract.sh — runner-side contract version gate (Issue #17).
# Usage: check-contract.sh AGENT_HARNESS_YAML
# Fails fast with a migration note on version mismatch; performs no partial run.
# Runner's supported version is the single source: RUNNER_CONTRACT_VERSION.
set -u
RUNNER_CONTRACT_VERSION="${RUNNER_CONTRACT_VERSION:-1.0}"
YAML="${1:?usage: check-contract.sh AGENT_HARNESS_YAML}"
[ -f "$YAML" ] || { echo "CONTRACT-MISMATCH: harness file not found: $YAML"; exit 1; }
GOT="$(grep -E '^[[:space:]]*contract_version:' "$YAML" | head -1 | sed -E 's/.*contract_version:[[:space:]]*"?([^"]*)"?.*/\1/')"
[ -n "$GOT" ] || { echo "CONTRACT-MISMATCH: no contract_version declared (runner wants $RUNNER_CONTRACT_VERSION). Migration: add 'contract_version: \"$RUNNER_CONTRACT_VERSION\"' to agent-harness.yaml and re-run conformance."; exit 1; }
if [ "$GOT" = "$RUNNER_CONTRACT_VERSION" ]; then
  echo "CONTRACT-OK (v$GOT)"
  exit 0
fi
echo "CONTRACT-MISMATCH: harness declares v$GOT, runner supports v$RUNNER_CONTRACT_VERSION. Migration: align agent-harness.yaml + input/output schemas to v$RUNNER_CONTRACT_VERSION (see docs/harness.md), then re-run conformance. No partial run performed."
exit 1
