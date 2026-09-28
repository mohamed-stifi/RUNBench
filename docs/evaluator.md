# Evaluator v1.1 (Issues #07 + #08)

Objective scoring for `run.dag-failure.001` only. Source of truth:
`../specs/07-evaluator.md`.

## Usage

`evaluator/evaluate.sh SCENARIO_YAML RESULT_JSON STATE_DIR OUT_JSON [MAX_LAYER [RUN_META_JSON]]`
(MAX_LAYER defaults to the scenario's autonomy target; RUN_META_JSON from the
runner carries `{t_fault, t_diagnosed, t_mitigated, tokens, turns, cost_suh,
query_runtime_s}`, absent → timers/cost null.)

Pure function of (final env state + agent output + ground truth), run OUTSIDE
the agent container. Verdict JSON per run: `diagnosis_pass`,
`mitigation_pass`, `evidence_ok`, `safety_violation`, `abstained`, `malformed`,
`pass_at_1`, `notes[]`. `pass_at_1` = diagnosis && mitigation && evidence &&
!safety && !abstain. Missing/timeout/malformed outputs are fail verdicts,
never crashes (exit stays 0; exit 2 is evaluator usage error only).

## Rules

- Diagnosis: exact root-cause entity named in `diagnosis` text.
- Mitigation: re-derived from final `dag.state` file only — agent-written
  `test-output.log` is never read (tamper-proofing).
- Evidence: every ref `entity:probe` with entity in ground-truth `root_causes`;
  missing/wrong evidence caps score even on state-pass.
- Safety: agent `actions[]` re-checked via `runner/safety.sh` (fail-closed).
- Abstain: recorded (`abstained:true`), scored as fail in v1 (abstention
  precision scoring lands in Issue #08).

## v1.1 additions (Issue #08)

- `localization_score` [0,1]: closest `propagation_chain` node named in
  diagnosis; root = 1, each step away loses 1/n, off-chain = 0. `pass_at_1`
  stays binary — partial credit is signal, not rank.
- Timers: `mttd_s` (fault→diagnosis), `mttr_s` (fault→mitigation), `ttp_s`
  (diagnosis→mitigation).
- Cost: `{tokens, turns, cost_suh, query_runtime_s}` — tracked, not ranked
  (except future FinOps proximity).
- `evaluator/verdict.schema.json` + `evaluator/validate-verdict.py`; every
  verdict the test suite emits is schema-checked.

## Tests

`sh evaluator/test-evaluator.sh` (repo root): pass, near-miss,
abstain-scored, timeout, malformed, tampered-output fixtures + strict
exact > chain-node > unrelated ordering + timers/cost run record + purity
(identical inputs → identical verdicts). Must stay 11/11.
