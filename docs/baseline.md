# Baseline reference agent (Issue #14)

`agents/baseline/` — rule-based reference using only `tools/obs.sh`
(tools-not-raw-CLI). Source of truth: `../specs/06-agent-harness.md`
(baseline tools), `../specs/05-environment.md` (unified observability).

## Run

- Replay: `SNAPSHOT_DIR=<snap> sh agents/baseline/run.sh [IN [OUT]]`, or
  `make replay SCENARIO=run.dag-failure.001 REPLAY_AGENT=baseline`.
- Live: `sh agents/baseline/run.sh` (uses `$OBS_AIRFLOW_URL`/`$OBS_SPARK_URL`,
  default `localhost:18081/18082`); auto-detects a snapshot cwd.
- Entry/exit matches the harness contract (`harness/agent-harness.yaml`);
  output self-validates via `harness/validate.py`.

## Expected score (the split is the point)

Diagnosis passes (executor-OOM signature → names
`spark.config.spark.executor.memory` with a `probe_diagnosis_exact` evidence
link); mitigation fails (read-only, never fixes). So
null (loc 0.00, abstain) < baseline (loc 1.00, pass false) < oracle (pass true).

## Tool policy (timeout + truncation)

- Every source: `curl -m 5` live; local reads in snapshot mode; unknown source
  exits 2.
- Every output streams through `tools/summarize.sh` (default cap 50 lines /
  4000 chars, head + `[truncated ...]` marker) — context-overflow handling.
- Read-only: no PUT/POST/DELETE, no docker/kubectl, no state writes; respects
  `../specs/03-autonomy-layers.md` guardrails.

## Tests

`sh agents/baseline/test-baseline.sh` (repo root, no docker): tool policy
checks + end-to-end (snapshot → run → validate → evaluate) with the strict
null < baseline < oracle ordering. Must stay 9/9.
