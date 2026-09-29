#!/bin/sh
# release.sh — tag a leaderboard release (Issue #11).
# Writes leaderboard/releases/<TAG>.json {dataset_tag, scenario_tags,
# board_sha256, date, entries} and prints the git-tag convention
# (dataset@<tag>). The manifest pins exactly which board the tag means;
# history stays append-only (releases are new files, never edits).
# Quarantined scenarios (leaderboard/quarantine.json) block release, not merge.
# Usage: release.sh BOARD_JSON TAG [OUT_ROOT]
set -eu
BOARD="${1:?usage: release.sh BOARD_JSON TAG [OUT_ROOT]}"
TAG="${2:?usage: release.sh BOARD_JSON TAG [OUT_ROOT]}"
OUT_ROOT="${3:-leaderboard/releases}"
PY=".venv/bin/python"; [ -x "$PY" ] || PY="python3"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
"$PY" - "$BOARD" "${QUARANTINE_JSON:-$ROOT/leaderboard/quarantine.json}" <<'EOF'
import json, sys
board = json.load(open(sys.argv[1]))
try:
    quar = {q["scenario_id"]: q for q in json.load(open(sys.argv[2])).get("quarantined", [])}
except FileNotFoundError:
    quar = {}
hit = sorted({e["scenario_id"] for e in board["entries"]} & set(quar))
if hit:
    for s in hit:
        print(f"GATE-FAIL: release blocked — {s} quarantined: {quar[s].get('reason')} (log: {quar[s].get('log')})", file=sys.stderr)
    sys.exit(1)
EOF
mkdir -p "$OUT_ROOT"
"$PY" - "$BOARD" "$OUT_ROOT/$TAG.json" "$TAG" <<'EOF'
import hashlib, json, sys, datetime
board = json.load(open(sys.argv[1]))
sha = hashlib.sha256(open(sys.argv[1], "rb").read()).hexdigest()
man = {"release_tag": f"dataset@{sys.argv[3]}",
       "dataset_tag": board["dataset_tag"], "board_version": board["board_version"],
       "board_sha256": sha,
       "scenario_tags": sorted({f"{e['scenario_id']}@{e['scenario_tag']}" for e in board["entries"]}),
       "date": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
       "entries": len(board["entries"])}
json.dump(man, open(sys.argv[2], "w"), indent=2)
print(f"RELEASE-OK dataset@{sys.argv[3]} ({man['entries']} entries, board {sha[:12]})")
print(f"convention: git tag -a dataset@{sys.argv[3]} -m 'leaderboard release'")
EOF
