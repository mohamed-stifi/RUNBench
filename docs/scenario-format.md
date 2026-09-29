# Scenario format `<M,E,T,D>` (Issue #16)

Thin mirror of [`../specs/04-scenario-spec.md`](../specs/04-scenario-spec.md)
+ `schemas/scenario.schema.json` (source of truth). Borrowed from ITBench
`p = <M,E,T,D>`: Metadata, Environment, Trigger/Task, aDjudication
(ground truth + oracle).

```yaml
id: run.<class-slug>.NNN        # M: identity
class: <one of the 10 RUN classes>
complexity: medium
autonomy: { start: L1, target: L4 }
platforms: [airflow, spark, yarn]
metadata: { description, tags, version: 0.1.0 }
environment:                     # E: reproducible runtime
  image: cdp-slim:0.1.0
  services: [airflow, spark, yarn]
  seed: 7                        # pinned (determinism gate)
trigger: { event, alert_ref, ... }  # T: what starts the incident
task: { goal, budget: { time_min, steps } }
ground_truth:                    # D: adjudication
  root_causes: [entity ids]
  propagation_chain: [config → fault → task failed → dagrun failed]
  fix_variants: [...]
safety: { allowed_verbs, gated_verbs, abstain_allowed }
blast_radius: [...]
oracle: { fault_inject, solution, test, status: stub|ready }
```

Validate with `sh bin/scenario validate scenarios/<id>.yaml`. Full
worked example: `scenarios/run.dag-failure.001.yaml`. To add one, follow
[`add-scenario.md`](add-scenario.md) — and copy the starter
[`../scenarios/_template/scenario.yaml`](../scenarios/_template/scenario.yaml).
