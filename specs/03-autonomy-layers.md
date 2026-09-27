# 03 — Autonomy Layers L0-L5

## Definitions

- **L0 Manual:** human acts, agent only observes/logs.
- **L1 Assist:** agent suggests diagnosis/next step, human approves. Read-only tools.
- **L2 Supervised:** agent acts on pre-approved playbooks, human on-call. Reversible only.
- **L3 Conditional:** agent acts autonomously within policy/queue/window, escalates novel/risky cases.
- **L4 High:** agent handles full incident class end-to-end, human audits post-hoc. Gated verbs only (no retention delete).
- **L5 Full:** agent operates class autonomously, including policy improvement. No human in loop.

## Rules

- Each scenario declares `start_layer` and `target_layer` (from `tasks-examples.md`).
- Agent declares `max_layer` it claims. Runner enforces tool/guardrail subset per layer.
- Promotion L(n)->L(n+1) requires: `pass@1` + evidence + abstention precision thresholds on hidden set, multi-trial.
- Irreversible verbs (retention delete, Ranger grant, mass kill) never exceed L4 in v1; FinOps tuning caps at L3.

See `09-task-classes.md` for per-class Start->Target and stop reasons.
