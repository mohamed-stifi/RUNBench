#!/usr/bin/env python3
"""query.py — filter spec implementation for the leaderboard (Issue #11).

Usage: query.py BOARD_JSON [--agent A] [--agent-version AV] [--scenario S]
  [--class C] [--complexity X] [--layer L] [--mode M] [--split SP]
  [--min-trials N] [--min-resolved PCT]
Covers every DoD filter dimension (agent/version/model, scenario/class/
complexity/L-layer, metrics). Prints a markdown table of matching entries.
"""
import json
import sys
from pathlib import Path


def main():
    if len(sys.argv) < 2:
        print(__doc__, file=sys.stderr)
        return 2
    board = json.loads(Path(sys.argv[1]).read_text())
    flt = {}
    args = sys.argv[2:]
    while args:
        a = args.pop(0)
        if not a.startswith("--") or not args:
            print(f"query ERROR: bad filter {a}", file=sys.stderr)
            return 2
        flt[a[2:].replace("-", "_")] = args.pop(0)
    rows = []
    for e in board["entries"]:
        if "agent" in flt and e["agent"] != flt["agent"]:
            continue
        if "agent_version" in flt and e["agent_version"] != flt["agent_version"]:
            continue
        if "scenario" in flt and e["scenario_id"] != flt["scenario"]:
            continue
        if "class" in flt and e["task_class"] != flt["class"]:
            continue
        if "complexity" in flt and e["complexity"] != flt["complexity"]:
            continue
        if "layer" in flt and str(e["autonomy_layer"]) != flt["layer"]:
            continue
        if "mode" in flt and e["mode"] != flt["mode"]:
            continue
        if "split" in flt and e["split"] != flt["split"]:
            continue
        if "min_trials" in flt and e["trials"] < int(flt["min_trials"]):
            continue
        if "min_resolved" in flt and e["resolved_pct"] < float(flt["min_resolved"]):
            continue
        rows.append(e)
    print("| agent | scenario | split | trials | %Resolved | partial | MTTR | abstain |")
    print("|---|---|---|---|---|---|---|---|")
    for e in rows:
        mttr = "∞" if e["mttr_unresolved"] else str(e["mttr_s_mean"])
        print(f"| {e['agent_version']} | {e['scenario_id']} | {e['split']} | {e['trials']} "
              f"| {e['resolved_pct']:.0f} | {e['partial_mean']:.2f} | {mttr} | {e['abstain_rate']:.2f} |")
    print(f"\n{len(rows)} of {len(board['entries'])} entries match.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
