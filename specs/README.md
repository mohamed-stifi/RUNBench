# Specs — Data-Ops Agent Benchmark

Source of truth for system target. Lives in `specs/`.
See `AGENTS.md` for Goal, DoD, conventions.

## Index

- `01-overview.md` — goal, scope, principles, DoD
- `02-architecture.md` — 5 components + contracts
- `03-autonomy-layers.md` — L0-L5 definitions
- `04-scenario-spec.md` — scenario format `<M,E,T,D>`
- `05-environment.md` — reproducible CDP runtime
- `06-agent-harness.md` — pluggable agent interface
- `07-evaluator.md` — scoring, abstention, evidence
- `08-leaderboard.md` — versioning, filtering, dashboard
- `09-task-classes.md` — RUN classes from `tasks-examples.md`

## Rules

- Specs guide implementation + docs. When specs change, adapt both.
- Keep files short, structured, agent-readable.
- Inspired by ITBench: reuse `<M,E,T,D>`, file-contract harness, fault library, `pass@1` + partial credit, hidden + open sets, multi-trial CI.
