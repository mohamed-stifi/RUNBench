# Agent harness contract (Issue #06)

File contract between core and agent harness. Source of truth:
`../specs/06-agent-harness.md`. The harness is implemented separately; any
agent plugs in by honoring `harness/agent-harness.yaml`.

## Contract

- `harness/agent-harness.yaml` — `input_path` (`/in/scenario_data.json`),
  `output_path` (`/out/result.json`), `run.command`, `timeout_min`, budget,
  schema pointers.
- `harness/scenario-data.schema.json` — input: `scenario_id`, `goal_template`,
  `vars`, `autonomy_max` (0-5), `budget{time_min, steps}`.
- `harness/result.schema.json` — output: `diagnosis`, `actions[]`,
  `evidence_refs[]`, `abstained`, `abstain_reason`. Non-abstained results need a
  non-empty diagnosis; abstained results need a non-empty reason.
- `harness/validate.py RESULT_JSON` — harness-side validation, clear
  `HARNESS-INVALID: field '<path>': ...` errors. Exit 0 valid, 1 invalid.

## Null-agent fixture

`harness/null-agent/run.sh [IN [OUT]]` — always abstains with reason, validates
its own output, exits 0. Pipeline-testing baseline (no tools yet; NL2*
tool implementations land later).

## Tests

`sh harness/test-harness.sh` (repo root): null-agent on the sample input emits
valid `result.json` exit 0; the invalid fixture fails with per-field errors.
Must stay 8/8.

## Contract versioning + conformance (Issue #17)

- `contract_version: "1.0"` in `agent-harness.yaml` and both schemas (const).
  `harness/check-contract.sh` fails fast with a migration note on mismatch —
  no partial run. Bump all three together; never accept silently.
- `harness/gate-action.sh SCENARIO_YAML VERB TARGET LAYER` — orchestrator
  pre-execution gate (one action checked before it runs; `safety.sh` scores
  full traces after).
- `harness/conformance.sh SCENARIO_YAML AGENT_RESULT_JSON` — evaluator-side
  stage: copies output read-only (`:ro` mount in containers), validates,
  rejects `..`/absolute paths, cross-checks `evidence_refs` (`entity:probe`
  with entity in ground-truth `root_causes`). Forged pass claims score fail;
  abstain passes. Green required before board listing.
- `sh harness/test-harness.sh` 8/8 + `sh harness/test-conformance.sh` 13/13.
