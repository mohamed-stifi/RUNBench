# RUNBench

Systematic benchmarking framework for AI agents automating data operations
(Cloudera CDP · Airflow · Spark · Impala · Hive · Ozone · NiFi).
Specs are the source of truth — start at [`specs/`](specs/).

## Goal

Evaluate AI agents tasked with automating data operations — from triage to
remediation — on reproducible Cloudera CDP runtimes, and rank them on a
versioned leaderboard. Five components: **Agent** (system under test) →
**Scenario** (declarative task + ground truth) → **Environment** (seeded
CDP runtime) → **Evaluator** (execution-based scoring, outside the agent
container) → **Leaderboard** (comparable records across agents, scenarios,
autonomy layers L0–L5). Done when any agent plugs in without core changes,
any scenario is addable (`docs/add-scenario.md`), and results are
filterable by agent/scenario/layer/metrics. End goal: zero humans in the
operating loop.

## Layout

| Path | What lives here | Spec |
|---|---|---|
| `specs/` | Source of truth: architecture, scenario format, env, harness, evaluator, leaderboard | `specs/README.md` |
| `docs/` | Human/agent guides (index + contributor guides) | Issue #16 |
| `scenarios/` | Scenario specs (`<id>.yaml`) + task dirs (`task.toml`, `instruction.md`, `Dockerfile`, `solution/`, `tests/`) | `specs/04-scenario-spec.md` |
| `schemas/` | Scenario JSON Schema + `validate.py` (Issue #02; needs `.venv`) | `specs/04-scenario-spec.md` |
| `env/` | Reproducible CDP runtime + fault injection (Issue #04) | `specs/05-environment.md` |
| `harness/` | Agent file contract: input JSON in, result file out (Issue #06) | `specs/06-agent-harness.md` |
| `evaluator/` | External scoring vs ground truth (Issue #07) | `specs/07-evaluator.md` |
| `runner/` | select → provision → inject → run → evaluate → record (Issue #10) | `specs/02-architecture.md` |
| `leaderboard/` | Immutable run records + versioned board (Issue #11) | `specs/08-leaderboard.md` |
| `bin/` | CLIs (`scenario validate`, …) | Issues #01, #02 |

Task dirs follow the Harbor contract: `solution/` + `tests/` are mounted
`:ro` at verify time and never baked into the image.

## Quickstart

```sh
uv venv .venv && uv pip install -r requirements.txt
sh bin/scenario validate scenarios/run.dag-failure.001.yaml
# → run.dag-failure.001 0.1.0
```

## Testing

Prereqs: Docker daemon for live runs; everything else is docker-free
(replay/oracles fall back to seeded fixtures). Python via `.venv` above.

| Command | What it proves | Needs Docker |
|---|---|---|
| `sh scenarios/test-all.sh` | all 11 scenarios validate + oracle-5x + evaluator-pass (33 checks) | no |
| `sh ci/test-gates.sh` | every CI gate fails on broken fixtures, passes on main (22 checks) | no |
| `sh docs/test-docs.sh` | index links, guide refs, coverage matrix in sync (4 checks) | no |
| `sh leaderboard/test-leaderboard.sh` | board splits/CI/filters/releases (12 checks; live pass skipped w/o daemon) | optional |
| `sh <area>/test-*.sh` | per-component suites (evaluator, safety, harness, …) next to the code | no |

End-to-end live run (proves the full loop select→run→evaluate→record):

```sh
make start-scenario SCENARIO=run.dag-failure.001   # env + fault injection
sh runner/run.sh run.dag-failure.001 oracle 7 1 --live
make stop-scenario                                  # zero containers left
```

Docker-free replay + board:

```sh
make replay SCENARIO=run.dag-failure.001            # deterministic N runs
.venv/bin/python leaderboard/build.py runs/runlog.jsonl leaderboard/board.json --md leaderboard/LEADERBOARD.md
```

New scenarios: follow [`docs/add-scenario.md`](docs/add-scenario.md) only;
CI (`.github/workflows/ci.yml`) enforces validate, oracle-5x,
contamination, secrets, and append-only history on every PR.
