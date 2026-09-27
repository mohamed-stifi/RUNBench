# 05 — Environment

## Runtime (v1 slim, roadmap full CDP)

- Per-scenario Docker/Compose image, pinned by tag. Slim mock first: Airflow + Spark + Hive metastore + Impala stub + Ozone stub + Ranger stub + YARN stub.
- Provisioning: IaC (Ansible/Helm or Compose) + `fault-inject.sh` after waiters. Seed fixed.
- Observability unified behind one API: logs, metrics, traces, lineage, CLI/SQL/UI state (BrowserGym pattern).

## Reproducibility

- `image:tag + scenario_tag + seed` fully pins run. Oracle `solution.sh` must pass Nx.
- Snapshot & replay (ITBench-AA pattern): capture alerts/events/traces/metrics/topology for deterministic diagnosis-only mode. Live mode is nondeterministic — report multi-trial CI.
- Long jobs: timeout per scenario, checkpoint states; v1 caps at 60 min.

## Isolation / Safety

- Agent container sandboxed, no secrets in task config, evaluator runs outside.
- Guardrail engine enforces per-layer verbs (see `03-autonomy-layers.md`). Destructive fix without approval = fail.
