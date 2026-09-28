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
