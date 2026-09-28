# Leaderboard (dataset@run.dag-failure.001-0.1.0)

Single Trial: one run per entry (no CI — noise expected, paper §4.4). Multiple Trials: mean ± 95% CI with σ and trial count. MTTR ∞ = nothing resolved. $ cost needs a pricing model (deferred); SU·h is the compute column.

## Single Trial

| agent | scenario | %Resolved | pass_rate±CI95 | partial | MTTD | MTTR | tokens | wall-s | SU·h | abstain | evid | date |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| oracle@d7bb3d6 | run.dag-failure.001@0.1.0 | 0 | 0.00 (n=1) | 1.00 | 1.0 | ∞ | – | 1.0 | – | 0.00 | 1.00 | 2026-09-28 |

## Multiple Trials

| agent | scenario | %Resolved | pass_rate±CI95 | partial | MTTD | MTTR | tokens | wall-s | SU·h | abstain | evid | date |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| null@d7bb3d6 | run.dag-failure.001@0.1.0 | 0 | 0.00±0.00 (σ=0.00, n=3) | 0.00 | 1.0 | ∞ | – | 1.0 | – | 1.00 | 0.00 | 2026-09-28 |

Board v1.0. Filter spec: see ../docs/leaderboard.md. Append-only: rebuilds preserve run_ids.
