# Snapshot & replay (Issue #13)

Deterministic diagnosis-only eval without live services. Source of truth:
`../specs/05-environment.md` (ITBench-AA offline snapshot pattern; live mode
is nondeterministic — paper §4.4).

## Layout

`env/snapshots/<scenario>/snap-seed<SEED>/`: `manifest.json`
(`scenario_tag`, seed, captured-vs-live-only lists), `scenario.slice.yaml`
(frozen spec copy), `state/` (dag/task/app states), `alerts.json`,
`events.json`, `logs-tail.txt`, `metrics.json`, `lineage.slice.yaml`,
`topology.json`. Read-only (`chmod -R a-w`).

## Usage

- Live: `make start-scenario SCENARIO=...` → `make snapshot SCENARIO=... [SEED=7]`.
- Offline (tests/CI): `sh env/snapshot/capture.sh --from-state STATE_DIR run.dag-failure.001 [SEED] [OUT]`.
- Replay (opt-in; live stays default): `make replay SCENARIO=run.dag-failure.001 [REPLAY_AGENT=null] [SEED=7] [N=3]` — N agent runs against the RO snapshot, outputs must be diff-clean, then one verdict via `evaluator/evaluate.sh` with `state/` as the frozen world.

## Captured vs live-only

Captured: alert/event/metrics slices, logs tail, lineage slice, topology,
frozen states — everything the null/oracle diagnosis path needs. Live-only
(never in snapshots): streaming logs/metrics, container internals, wall-clock
timing, interactive shells/queries. Replay is diagnosis-only by design.

## Tests

`sh env/snapshot/test-snapshot.sh` (repo root, no docker needed): offline
capture, RO enforcement, re-capture determinism (modulo `captured_at`),
3× replay diff-clean, harness-side validation, identical abstain verdicts,
zero-live-container guard. Must stay 11/11.
