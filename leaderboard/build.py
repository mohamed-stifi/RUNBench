#!/usr/bin/env python3
"""build.py — runner runlog.jsonl -> leaderboard board.json + LEADERBOARD.md.

Usage: build.py RUNLOG BOARD_JSON [--md LEADERBOARD_MD] [--dataset-tag TAG]
Groups records by (agent_version, scenario_id, scenario_tag, mode); one board
entry per group (split single when trials==1 else multiple). Appends/updates
by group key only — per-run history (run_ids) is preserved, never overwritten.
Stats: pass_rate, resolved_pct, partial(localization)_mean, mttd/mttr means
over resolved runs (MTTR unresolved convention: mttr_s_mean null +
mttr_unresolved true, rendered as infinity), 95% CI + sigma on pass_rate for
multiple splits (null for single), cost means (nulls skipped), abstain_rate,
evidence_score (fraction evidence_ok true). Every entry schema-validated.
"""
import datetime
import json
import math
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BOARD_VERSION = "1.0"


def scen_meta(scenario_id):
    p = ROOT / "scenarios" / f"{scenario_id}.yaml"
    txt = p.read_text()
    get = lambda k: (re.search(rf"^{k}:\s*(.+)$", txt, re.M) or [None, ""])[1].strip().strip("'\"")
    m = re.search(r"target:\s*L?(\d)", txt)
    return {"task_class": get("class") or "unknown", "complexity": get("complexity") or "unknown",
            "autonomy_layer": int(m.group(1)) if m else None, "scenario_tag": get("version") or "unknown"}


def mean(xs):
    xs = [x for x in xs if x is not None]
    return sum(xs) / len(xs) if xs else None


def main():
    if len(sys.argv) < 3:
        print("usage: build.py RUNLOG BOARD_JSON [--md LEADERBOARD_MD] [--dataset-tag TAG]", file=sys.stderr)
        return 2
    runlog, board_p = Path(sys.argv[1]), Path(sys.argv[2])
    md_p, dataset_tag = None, None
    args = sys.argv[3:]
    while args:
        a = args.pop(0)
        if a == "--md":
            md_p = Path(args.pop(0))
        elif a == "--dataset-tag":
            dataset_tag = args.pop(0)
    try:
        import jsonschema
    except ImportError:
        print("build ERROR: jsonschema not installed (need .venv)", file=sys.stderr)
        return 2
    schema = json.loads((ROOT / "leaderboard" / "record.schema.json").read_text())
    records = [json.loads(l) for l in runlog.read_text().splitlines() if l.strip()]
    if dataset_tag is None:
        tags = sorted({f"{r['scenario_id']}-{r['scenario_tag']}" for r in records})
        dataset_tag = "dataset@" + "+".join(tags) if tags else "dataset@empty"
    groups = {}
    for r in records:
        groups.setdefault((r["agent_version"], r["scenario_id"], r["scenario_tag"], r["mode"]), []).append(r)
    entries = []
    for (aver, sid, stag, mode), rs in sorted(groups.items()):
        meta = scen_meta(sid)
        n = len(rs)
        passes = sum(1 for r in rs if r["status"] == "pass")
        pr = passes / n
        if n > 1:
            var = sum(( (1 if r["status"] == "pass" else 0) - pr) ** 2 for r in rs) / (n - 1)
            sigma = math.sqrt(var)
            ci = 1.96 * sigma / math.sqrt(n)
        else:
            sigma, ci = None, None
        mttrs = [r["verdict"]["mttr_s"] for r in rs if r["status"] == "pass" and r["verdict"].get("mttr_s") is not None]
        entry = {
            "agent": rs[0]["agent"], "agent_version": aver, "model": None,
            "scenario_id": sid, "scenario_tag": stag, "dataset_tag": dataset_tag,
            "task_class": meta["task_class"], "complexity": meta["complexity"],
            "autonomy_layer": meta["autonomy_layer"], "mode": mode,
            "split": "single" if n == 1 else "multiple", "trials": n,
            "pass_rate": round(pr, 4), "resolved_pct": round(100 * pr, 2),
            "partial_mean": round(mean([r["verdict"]["localization_score"] for r in rs]) or 0, 4),
            "mttd_s_mean": mean([r["verdict"].get("mttd_s") for r in rs]),
            "mttr_s_mean": mean(mttrs) if mttrs else None,
            "mttr_unresolved": not mttrs,
            "ci95": round(ci, 4) if ci is not None else None,
            "sigma": round(sigma, 4) if sigma is not None else None,
            "cost": {
                "tokens_mean": mean([r["verdict"]["cost"].get("tokens") for r in rs]),
                "wallclock_s_mean": mean([r["verdict"]["cost"].get("query_runtime_s") for r in rs]),
                "suh_mean": mean([r["verdict"]["cost"].get("cost_suh") for r in rs]),
            },
            "abstain_rate": round(sum(1 for r in rs if r["status"] == "abstained") / n, 4),
            "evidence_score": round(sum(1 for r in rs if r["verdict"].get("evidence_ok")) / n, 4),
            "date": max(r["date"] for r in rs),
            "run_ids": sorted({r["run_id"] for r in rs}),
            "board_version": BOARD_VERSION,
        }
        errs = list(jsonschema.Draft202012Validator(schema).iter_errors(entry))
        if errs:
            print(f"build ERROR: entry {aver}/{sid} invalid: {errs[0].message}", file=sys.stderr)
            return 1
        entries.append(entry)
    board_p.parent.mkdir(parents=True, exist_ok=True)
    board_p.write_text(json.dumps({"dataset_tag": dataset_tag, "board_version": BOARD_VERSION,
                                   "date": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
                                   "entries": entries}, indent=2) + "\n")
    if md_p:
        md_p.write_text(render_md(dataset_tag, entries))
    print(f"BOARD-OK {len(entries)} entries ({sum(e['trials'] for e in entries)} trials) -> {board_p}")


def render_md(dataset_tag, entries):
    dash = lambda v: "–" if v is None else str(v)
    def row(e, split):
        mttr = "∞" if e["mttr_unresolved"] else str(e["mttr_s_mean"])
        ci = f"{e['pass_rate']:.2f}±{e['ci95']:.2f} (σ={e['sigma']:.2f}, n={e['trials']})" if e["ci95"] is not None else f"{e['pass_rate']:.2f} (n=1)"
        c = e["cost"]
        return (f"| {e['agent_version']} | {e['scenario_id']}@{e['scenario_tag']} | {e['resolved_pct']:.0f} "
                f"| {ci} | {e['partial_mean']:.2f} | {dash(e['mttd_s_mean'])} | {mttr} "
                f"| {dash(c['tokens_mean'])} | {dash(c['wallclock_s_mean'])} | {dash(c['suh_mean'])} "
                f"| {e['abstain_rate']:.2f} | {e['evidence_score']:.2f} | {e['date'][:10]} |")
    hdr = "| agent | scenario | %Resolved | pass_rate±CI95 | partial | MTTD | MTTR | tokens | wall-s | SU·h | abstain | evid | date |"
    sep = "|---|---|---|---|---|---|---|---|---|---|---|---|---|"
    out = [f"# Leaderboard ({dataset_tag})", "",
           "Single Trial: one run per entry (no CI — noise expected, paper §4.4). "
           "Multiple Trials: mean ± 95% CI with σ and trial count. MTTR ∞ = nothing resolved. "
           "$ cost needs a pricing model (deferred); SU·h is the compute column.",
           "", "## Single Trial", "", hdr, sep]
    out += [row(e, "single") for e in entries if e["split"] == "single"] or ["(none)"]
    out += ["", "## Multiple Trials", "", hdr, sep]
    out += [row(e, "multiple") for e in entries if e["split"] == "multiple"] or ["(none)"]
    out += ["", f"Board v{BOARD_VERSION}. Filter spec: see ../docs/leaderboard.md. Append-only: rebuilds preserve run_ids."]
    return "\n".join(out) + "\n"


if __name__ == "__main__":
    sys.exit(main())
