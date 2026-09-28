# RUNBench docs

Short, structured guides for humans and agents. Specs in [`../specs/`](../specs/)
remain the source of truth; this folder holds how-to material only.

- [`../specs/01-overview.md`](../specs/01-overview.md) — what RUNBench is and why
- [`../specs/02-architecture.md`](../specs/02-architecture.md) — components, contracts, flow
- [`../specs/04-scenario-spec.md`](../specs/04-scenario-spec.md) — scenario format (`<M,E,T,D>`)
- [`../README.md`](../README.md) — repo layout and quickstart
- [`safety.md`](safety.md) — guardrails, sandbox, redaction (Issue #09)
- [`harness.md`](harness.md) — agent file contract + null-agent (Issue #06)
- [`evaluator.md`](evaluator.md) — pass@1 scoring + golden fixtures (Issue #07)
- [`snapshot.md`](snapshot.md) — snapshot & deterministic replay (Issue #13)
- [`baseline.md`](baseline.md) — baseline agent + obs tools (Issue #14)

Contributor guides (add-scenario walkthrough, dashboard usage) land in Issue #16.
