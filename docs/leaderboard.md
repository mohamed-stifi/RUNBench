# Leaderboard (Issue #11)

Comparable, versioned results. Source of truth: `../specs/08-leaderboard.md`.
Sample board: [`LEADERBOARD.md`](../leaderboard/LEADERBOARD.md) (replay-only).

## Pipeline

`runs/runlog.jsonl` (Issue #10) → `leaderboard/build.py RUNLOG board.json
[--md LEADERBOARD.md]` → entries grouped by
(agent_version, scenario, scenario_tag, mode), split single (n=1, no CI) vs
multiple (mean ± 95% CI + σ + n). Every entry validated against
`leaderboard/record.schema.json`. Rebuilds are append-only (run_ids
preserved — asserted in tests).

## Columns

%Resolved, pass_rate±CI95, partial (localization mean), MTTD/MTTR means over
resolved runs (**∞** when nothing resolved), cost (tokens / wall-clock-s /
SU·h means from runner journals; **$ needs a pricing model — deferred**),
abstain rate, evidence score, date, run_ids (run links).

## Filters (dashboard spec, no full UI yet)

`leaderboard/query.py board.json` with `--agent/--agent-version/--scenario/
--class/--complexity/--layer/--mode/--split/--min-trials/--min-resolved` —
covers all DoD dimensions (agent/version/model, scenario/class/complexity/
L-layer, metrics).

## Releases

`leaderboard/release.sh board.json TAG` writes `releases/<TAG>.json`
(dataset_tag, scenario_tags, board sha256, entry count); tag the commit with
`git tag -a dataset@<TAG>`. Releases are new files — history immutable.

## Tests

`sh leaderboard/test-leaderboard.sh` (repo root): builds a sample runlog via
the runner (replay + one live pass when the daemon is reachable), checks
splits/CI/σ/∞/cost/filters/append-only/release. Must stay 12/12.
