#!/bin/sh
# sleeper — timeout fixture: never finishes (Issue #10).
# Usage: run.sh [IN OUT] (both ignored). Sleeps SLEEP_S (default 120).
set -u
sleep "${SLEEP_S:-120}"
