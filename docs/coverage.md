# Class coverage matrix (Issue #16, completed in Issue #12)

DevOps-Eval idea: track which of the 10 RUN classes
(`specs/09-task-classes.md`) has scenarios. Coverage rule v1: min 1
scenario per class — **met: 11 scenarios across all 10 classes**.
Expand high-volume first (alerts, DAG failures, data incidents).

| Task class | Slug | Start→Target | Scenarios | Split | Human baseline |
|---|---|---|---|---|---|
| Alert triage and enrichment | alert-triage | L1→L5 | run.alert-triage.001 | open | pending |
| Job and DAG failure diagnosis | dag-failure | L1→L4 | run.dag-failure.001, run.dag-failure.002 | open | pending |
| Data-incident triage and root cause | data-incident | L1→L4 | run.data-incident.001 | open | pending |
| Rerun, clear, backfill | rerun-backfill | L2→L4 | run.rerun-backfill.001 | open | pending |
| Runaway query control | runaway-query | L2→L3 | run.runaway-query.001 | open | pending |
| Service role restart and config change | service-restart | L2→L3 | run.service-restart.001 | open | pending |
| Access and policy requests | access-policy | L2→L4 | run.access-policy.001 | open | pending |
| User support | user-support | L1→L5 | run.user-support.001 | open | pending |
| Housekeeping | housekeeping | L2→L4 | run.housekeeping.001 | open | pending |
| Capacity, queues and cost | capacity-cost | L1→L3 | run.capacity-cost.001 | open | pending |

Split policy: `docs/contamination.md`. Human baselines: no human runs
collected yet — column reserved; record human trials the same way as agent
records (same `record.schema.json`, agent=`human`) when available.

`docs/test-docs.sh` asserts every `scenarios/*.yaml` id appears here, so
the matrix cannot drift from the tree.
