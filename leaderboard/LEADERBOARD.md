# Leaderboard (dataset@run.access-policy.001-0.1.0+run.alert-triage.001-0.1.0+run.capacity-cost.001-0.1.0+run.dag-failure.001-0.1.0+run.dag-failure.002-0.1.0+run.data-incident.001-0.1.0+run.housekeeping.001-0.1.0+run.rerun-backfill.001-0.1.0+run.runaway-query.001-0.1.0+run.service-restart.001-0.1.0+run.user-support.001-0.1.0)

Single Trial: one run per entry (no CI — noise expected, paper §4.4). Multiple Trials: mean ± 95% CI with σ and trial count. MTTR ∞ = nothing resolved. $ cost needs a pricing model (deferred); SU·h is the compute column.

## Single Trial

| agent | scenario | %Resolved | pass_rate±CI95 | partial | MTTD | MTTR | tokens | wall-s | SU·h | abstain | evid | date |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| oracle@464552c | run.dag-failure.001@0.1.0 | 0 | 0.00 (n=1) | 1.00 | 1.0 | ∞ | – | 1.0 | – | 0.00 | 1.00 | 2026-09-29 |

## Multiple Trials

| agent | scenario | %Resolved | pass_rate±CI95 | partial | MTTD | MTTR | tokens | wall-s | SU·h | abstain | evid | date |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| null@464552c | run.access-policy.001@0.1.0 | 0 | 0.00±0.00 (σ=0.00, n=3) | 0.00 | 1.0 | ∞ | – | 1.0 | – | 1.00 | 0.00 | 2026-09-29 |
| null@464552c | run.alert-triage.001@0.1.0 | 0 | 0.00±0.00 (σ=0.00, n=3) | 0.00 | 1.0 | ∞ | – | 1.0 | – | 1.00 | 0.00 | 2026-09-29 |
| null@464552c | run.capacity-cost.001@0.1.0 | 0 | 0.00±0.00 (σ=0.00, n=3) | 0.00 | 1.0 | ∞ | – | 1.0 | – | 1.00 | 0.00 | 2026-09-29 |
| null@464552c | run.dag-failure.001@0.1.0 | 0 | 0.00±0.00 (σ=0.00, n=3) | 0.00 | 1.0 | ∞ | – | 1.0 | – | 1.00 | 0.00 | 2026-09-29 |
| null@464552c | run.dag-failure.002@0.1.0 | 0 | 0.00±0.00 (σ=0.00, n=3) | 0.00 | 1.0 | ∞ | – | 1.0 | – | 1.00 | 0.00 | 2026-09-29 |
| null@464552c | run.data-incident.001@0.1.0 | 0 | 0.00±0.00 (σ=0.00, n=3) | 0.00 | 1.0 | ∞ | – | 1.0 | – | 1.00 | 0.00 | 2026-09-29 |
| null@464552c | run.housekeeping.001@0.1.0 | 0 | 0.00±0.00 (σ=0.00, n=3) | 0.00 | 1.0 | ∞ | – | 1.0 | – | 1.00 | 0.00 | 2026-09-29 |
| null@464552c | run.rerun-backfill.001@0.1.0 | 0 | 0.00±0.00 (σ=0.00, n=3) | 0.00 | 1.0 | ∞ | – | 1.0 | – | 1.00 | 0.00 | 2026-09-29 |
| null@464552c | run.runaway-query.001@0.1.0 | 0 | 0.00±0.00 (σ=0.00, n=3) | 0.00 | 1.0 | ∞ | – | 1.0 | – | 1.00 | 0.00 | 2026-09-29 |
| null@464552c | run.service-restart.001@0.1.0 | 0 | 0.00±0.00 (σ=0.00, n=3) | 0.00 | 1.0 | ∞ | – | 1.0 | – | 1.00 | 0.00 | 2026-09-29 |
| null@464552c | run.user-support.001@0.1.0 | 0 | 0.00±0.00 (σ=0.00, n=3) | 0.00 | 1.0 | ∞ | – | 1.0 | – | 1.00 | 0.00 | 2026-09-29 |

Board v1.0. Filter spec: see ../docs/leaderboard.md. Append-only: rebuilds preserve run_ids.
