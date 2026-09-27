# 08 — Leaderboard

## Storage

- Immutable records, never overwrite: `{agent_version, scenario_tag, trials, pass@1, partial, MTTD/MTTR, cost, abstain_rate, evidence_score, date, run_link}`.
- Split `Single Trial` vs `Multiple Trials` (ITBench pattern). Verified runs only.

## Views

Filterable dashboard by:
- agent / agent_version / model
- scenario / class / complexity / autonomy layer L0-L5
- metrics: %Resolved, partial, MTTD/MTTR, cost, abstain precision

Report mean ± CI + σ + trials count. Tag releases like `dataset@tag` (Harbor/Terminal-Bench pattern).

## Anti-contamination

- 11/~N scenarios open-sampled, rest hidden. Public `solution.sh` only for open set.
- Human-baseline column per class where available.
