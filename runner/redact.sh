#!/bin/sh
# redact.sh — scrub secrets from agent traces/logs (Issue #09).
# Usage: redact.sh [FILE...]  (no args: stdin). Prints scrubbed text to stdout.
# Patterns: password/token/secret assignments, AWS access keys, PEM blocks,
# Ranger/CM credential-looking lines. Scan companion: test-safety.sh asserts
# that a secret-looking fixture is both redacted here AND flagged by scan.
set -u
sed -E \
  -e 's/((password|passwd|pwd|token|secret|api[_-]?key)[[:space:]]*[:=][[:space:]]*)[^[:space:]]+/\1[REDACTED]/gI' \
  -e 's/AKIA[0-9A-Z]{16}/[REDACTED-AWS-KEY]/g' \
  -e 's/(-----BEGIN [A-Z ]*PRIVATE KEY-----).*(-----END [A-Z ]*PRIVATE KEY-----)/\1[REDACTED]\2/' \
  -e 's/(ranger[_-]?|cloudera[_-]?manager[_-]?)(password|token|secret)[[:space:]]*[:=][[:space:]]*[^[:space:]]+/\1\2=[REDACTED]/gI' \
  "$@"
