# RUNBench

Systematic benchmarking framework for AI agents automating data operations
(Cloudera CDP · Airflow · Spark · Impala · Hive · Ozone · NiFi).
Specs are the source of truth — start at [`specs/`](specs/).

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
bin/scenario validate scenarios/examples/run.dag-failure.001.yaml
# → run.dag-failure.001 0.1.0
# Validate every scenario (CI gate in Issue #15):
find scenarios -name '*.yaml' -exec bin/scenario validate {} +
```
