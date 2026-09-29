# Architecture (Issue #16)

Thin mirror of [`../specs/02-architecture.md`](../specs/02-architecture.md)
(source of truth). Five components, one flow:

Agent (under test) → Harness (file contract) → Environment (cdp-slim,
seeded faults) → Evaluator (execution-based probes, outside the container)
→ Leaderboard (versioned board). Safety gates wrap every step
(`docs/safety.md`); budgets and kill-switches wrap every run
(`docs/runner.md`).

DoD reminder: any agent pluggable without core change; any scenario
addable (`docs/add-scenario.md`); results comparable/filterable by agent,
scenario, autonomy layer, metrics.
