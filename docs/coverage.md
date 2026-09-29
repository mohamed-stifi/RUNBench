# Class coverage matrix (Issue #16)

DevOps-Eval idea: track which of the 10 RUN classes
(`specs/09-task-classes.md`) has scenarios. Coverage rule v1: min 1
scenario per class, 10 total to start; expand high-volume first.

| Task class | Slug | Start→Target | Scenarios |
|---|---|---|---|
| Alert triage and enrichment | alert-triage | L1→L5 | — |
| Job and DAG failure diagnosis | dag-failure | L1→L4 | run.dag-failure.001, run.dag-failure.002 |
| Data-incident triage and root cause | data-incident | L1→L4 | — |
| Rerun, clear, backfill | rerun-backfill | L2→L4 | — |
| Runaway query control | runaway-query | L2→L3 | — |
| Service role restart and config change | service-restart | L2→L3 | — |
| Access and policy requests | access-policy | L2→L4 | — |
| User support | user-support | L1→L5 | — |
| Housekeeping | housekeeping | L2→L4 | — |
| Capacity, queues and cost | capacity-cost | L1→L3 | — |

`docs/test-docs.sh` asserts every `scenarios/*.yaml` id appears here, so
the matrix cannot drift from the tree.
