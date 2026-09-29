# Contamination policy: hidden vs open split (Issue #12)

ITBench precedent: hidden set + small open-sampled subset
anti-contamination; Big-Bench canary strings. Our split:

## Open set (tracked, `open-set` tag, canary-marked)

All 11 v1 scenarios: run.dag-failure.001, run.dag-failure.002,
run.alert-triage.001, run.data-incident.001, run.rerun-backfill.001,
run.runaway-query.001, run.service-restart.001, run.access-policy.001,
run.user-support.001, run.housekeeping.001, run.capacity-cost.001.
Every oracle script carries `RUNBENCH-CANARY 7f3a9c1e-…` so training
crawls can exclude benchmark data (`ci/check-canary.sh` enforces).

## Hidden set (private, never in this repo)

Hidden variants live **outside the repo** — no `hidden/` directory is
ever committed, and no public image `COPY`s oracle material
(`ci/check-hidden-split.sh` enforces both). A hidden variant reuses the
open scenario's shape with rotated entities/seeds; it is scored with the
same evaluator and its records land on the board with the same schema.

## Quarantine (flaky, not hidden)

Flaky scenarios are listed in `leaderboard/quarantine.json` with reason +
log. Quarantine blocks `release.sh` but not merge or board builds —
see `docs/ci.md`.
