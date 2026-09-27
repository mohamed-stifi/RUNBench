# 06 — Agent Harness

Bring-your-own-container + file contract (ITBench pattern). Harness implemented separately from core.

## Interface

- `agent-harness.yaml`:
  ```yaml
  input_path: /in/scenario_data.json   # {goal_template, vars{...}, autonomy_max, budget}
  output_path: /out/result.json        # {diagnosis, actions, evidence_refs, abstained: bool, abstain_reason}
  run: { command: "python -m agent.run", timeout_min: 60 }
  ```
- Loop: `reset(goal) -> step(obs) -> act` via tools (shell/SQL/API/UI). No raw prod access, only scenario env.
- Baseline tools (v1): `NL2Logs, NL2Metrics, NL2Lineage, NL2Airflow/Spark/Impala` + summarizer. Full CDP tools later.

## Registration

- Private repo + registration issue → runner builds harness image `FROM <agent-harness-base>`, runs against hosted/cluster env, posts results.
- Self-hosted: `SCENARIO=N make start-scenario` equivalent for CDP-slim.

## Rules

- Must support `abstain` action with reason + evidence pointers.
- Must emit evidence links for every claimed root cause (else evaluator penalizes).
- Versioned `agent_version`; model, tokens, cost, turns logged externally.
