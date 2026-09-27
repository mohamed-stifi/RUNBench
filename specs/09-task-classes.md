# 09 — Task Classes (RUN)

Derived from `tasks-examples.md`. Each maps to scenario IDs `run.<slug>.NNN`.

| Task class | Start | Target | Stop reason / gate |
|---|---|---|---|
| Alert triage and enrichment | L1 | L5 | Read-only, grade vs humans |
| Job and DAG failure diagnosis | L1 | L4 | Evidence-linked, abstention allowed |
| Data-incident triage and root cause | L1 | L4 | Rule results = ground truth, lineage impact |
| Rerun, clear, backfill | L2 | L4 | Idempotent, versioned runs only |
| Runaway query control | L2 | L3 | Kill has business impact, per-queue policy |
| Service role restart and config change | L2 | L3 | Cascade risk, maintenance window + undo |
| Access and policy requests | L2 | L4 | Standard patterns auto, novel stays L2 |
| User support (how-to, status, slow job) | L1 | L5 | Scripted flows |
| Housekeeping: small files, compaction, stats, retention | L2 | L4 | Delete irreversible, retention gated |
| Capacity, queues and cost | L1 | L3 | FinOps scored 0% publicly, keep human |

## Coverage rule (v1)

- Min 1 scenario per class, 10 total to start. Expand high-volume first (alerts, DAG failures, data incidents).
- Each scenario declares `safety.allowed_verbs` matching its row's gate.
