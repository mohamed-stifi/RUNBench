#!/bin/sh
# Probe for the hello-task fixture. Runs OUTSIDE the agent container.
# FAIL_TO_PASS: fails on the bare image, passes after solution output exists.
# POSIX sh: fixture images are slim (no bash).
set -eu

out="${1:-/tmp/hello-task-result.txt}"
grep -q 'hello-task' "$out" && grep -q '0.1.0' "$out"
