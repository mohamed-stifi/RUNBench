#!/bin/sh
# summarize.sh — output summarizer for context-overflow handling (Issue #14).
# Caps any tool stream to MAX_LINES lines / MAX_CHARS chars (defaults 50/4000),
# keeping head+tail with a [truncated ...] marker so the agent knows context
# was cut instead of silently losing it.
# Usage: some-tool ... | summarize.sh [MAX_LINES] [MAX_CHARS]
set -u
MAX_LINES="${1:-50}"
MAX_CHARS="${2:-4000}"
TMP="$(mktemp "${TMPDIR:-/tmp}/runbench-sum.XXXXXX")"
trap 'rm -f "$TMP"' EXIT INT TERM
cat > "$TMP"
lines="$(wc -l < "$TMP" | tr -d ' ')"
chars="$(wc -c < "$TMP" | tr -d ' ')"
if [ "$lines" -le "$MAX_LINES" ] && [ "$chars" -le "$MAX_CHARS" ]; then
  cat "$TMP"; exit 0
fi
head -n "$MAX_LINES" "$TMP" | cut -c "1-$MAX_CHARS"
echo "[truncated: ${lines} lines / ${chars} chars exceeded budget ${MAX_LINES} lines / ${MAX_CHARS} chars; showing head]"
