# Runner MVP (Issue #10)

Glue: select → provision → inject → run → evaluate → record. Source of truth:
`../specs/02-architecture.md` (flow), `../specs/08-leaderboard.md` (records).

## Usage

`sh runner/run.sh SCENARIO AGENT [SEED] [TRIALS] [--live]`
(AGENT `null|baseline|oracle|path-to-fixture`; default replay, 1 trial).
Knobs: `RUNLOG` (default `runs/runlog.jsonl`, git-ignored local artifact),
`RUN_TIMEOUT_S` (default 120), `RUN_MAX_TOKENS/_TURNS/_COST_SUH` (unset =
uncapped).

- Select gate: scenario validates + ships oracle `solution.sh`/`test.sh` +
  `safety:` guardrails, else unrunnable.
- Replay: per-trial offline snapshot, zero live containers. Live: compose
  up → wait → fault-inject per trial, post-run snapshot, teardown.
- Agent runs in background with a portable deadline watcher (no GNU timeout):
  deadline or budget breach → `kill -9` + recorded `timeout`/`budget_breach`
  (never a hang). Budgets read the agent sidecar `$OUT/run-meta.json`
  mid-run and post-run.
- Evaluator runs outside the agent container; runner-built run-meta supplies
  timers (`t_fault`=inject, `t_diagnosed`=result mtime approx, query time =
  agent wall-clock).
- Records append as single-line JSON (JSONL invariant) with embedded
  reproducibility journal (scenario_tag, seed, image digest, mode, agent cmd,
  timeout, budget, timestamps) — config re-derivable from the record alone.
  Multi-trial prints pass rate + mean localization + mean MTTR over resolved
  (CI lands in Issue #11).

## Status values

`pass` (pass@1) · `diagnosed` (diagnosis only — expected for oracle/baseline
in replay) · `abstained` · `fail` · `timeout` · `budget_breach`.

## Tests

`sh runner/test-runner.sh` (repo root): replay oracle/null records, record
schema + journal check, timeout kill (3s vs 120s sleep), mid-run budget kill
(2s vs 60s linger), immutability, per-trial append, JSONL invariant,
multi-trial means; live oracle → pass + live null → abstain when the daemon
is reachable (skipped otherwise). Must stay 13/13 (11 + 2 live).
