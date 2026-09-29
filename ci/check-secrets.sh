#!/bin/sh
# check-secrets.sh — secret-scan gate (Issue #15).
# Prefers gitleaks (CI installs the binary); falls back to a value-oriented
# grep (matches secret VALUES, not pattern definitions like runner/redact.sh).
# Usage: check-secrets.sh [DIR]
set -u
DIR="${1:-.}"
if command -v gitleaks >/dev/null 2>&1; then
  gitleaks detect --source "$DIR" --no-git -v || {
    echo "GATE-FAIL: gitleaks found leaked secrets under $DIR" >&2
    exit 1
  }
else
  hits="$(grep -rEn --exclude-dir=.git --exclude=check-secrets.sh --exclude=redact.sh \
    '(AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{36}|-----BEGIN [A-Z ]*PRIVATE KEY-----)' "$DIR" 2>/dev/null || true)"
  if [ -n "$hits" ]; then
    echo "GATE-FAIL: possible leaked secrets under $DIR:" >&2
    echo "$hits" >&2
    exit 1
  fi
fi
echo "SECRETS-OK"
