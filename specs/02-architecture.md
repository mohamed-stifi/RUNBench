# 02 — Architecture

Inspired by ITBench Fig.2: Scenario + Env, Agent, Evaluator, Leaderboard + Runner. Agent+Env modeled as POMDP.

## Components

1. **Scenario Specification** (`04-scenario-spec.md`)
   - In: task class + autonomy target. Out: declarative `<M,E,T,D>` YAML/JSON, validated by schema.
2. **Environment** (`05-environment.md`)
   - In: scenario spec. Out: live reproducible CDP runtime + obs (logs/metrics/traces/UI/CLI/SQL).
3. **AI Agent / Harness** (`06-agent-harness.md`)
   - In: `scenario_data.json` (goal + vars). Out: result file (diagnosis + actions + evidence + abstain flag).
   - Runs sandboxed, isolated from evaluator.
4. **Evaluator** (`07-evaluator.md`)
   - In: final state + agent output + ground truth. Out: `pass@1`, partial credit, MTTD/MTTR, cost, safety.
5. **Leaderboard + Runner** (`08-leaderboard.md`)
   - In: run results. Out: versioned, filterable board + dashboard.
   - Runner: selects scenarios, provisions env, injects fault, runs agent, calls evaluator.

## Contracts

- `Scenario -> Environment`: spec ID + tag pins image + fault script.
- `Runner -> Agent`: input JSON file, run command, timeout/budget.
- `Agent -> Evaluator`: output file (never direct DB access).
- `Evaluator -> Leaderboard`: immutable record `{agent_version, scenario_tag, trials, metrics, date}`.

## Flow

`select -> provision -> inject -> observe/act loop (until stop/timeout/abstain) -> evaluate outside container -> record`
