# 04 — Scenario Specification

Borrowed from ITBench tuple `p = <M,E,T,D>` + JSON schema + `disruptions[] / solutions[[]]`.

## Format (YAML/JSON, schema-validated)

```yaml
id: run.dag-failure.001
class: job-dag-failure-diagnosis
domain: RUN
complexity: medium        # expert label, calibrated over time
autonomy: { start: L1, target: L4 }
platforms: [airflow, spark, yarn]
metadata: { description, tags, version: 0.1.0 }
environment: { image: cdp-slim:0.1.0, services: [airflow, spark], seed: 42 }
trigger: { event: airflow_task_failed, alert_ref: ... }
task: { goal: "Diagnose failed DAG run, propose safe rerun", budget: { time_min: 60, steps: 50 } }
ground_truth:
  root_causes: [entity list]
  propagation_chain: [chain]
  expected_fix_variants: [[steps...]]
  probes:
    diagnosis_pass: { type: exact/lineage-distance, value: ... }
    mitigation_pass: { type: state-check, query: "airflow dags state ..." }
safety: { readonly: false, allowed_verbs: [rerun, clear], gated_verbs: [delete], abstain_allowed: true }
```

## Requirements

- Declarative only, no agent code inside.
- `solutions` lists variant fixes (like ITBench) for partial-credit scoring.
- `probes` are executable checks run outside agent container (Terminal-Bench pattern).
- Versioned `scenario_tag` (e.g. `run.dag-failure@0.1.0`), immutable. Hidden set + sampled open set to prevent contamination.
- Each scenario ships `fault-inject.sh` + `solution.sh` + `test.sh` oracle (oracle passes 5x pre-merge).
