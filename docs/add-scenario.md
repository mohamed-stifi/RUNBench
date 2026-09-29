# Add a scenario (Issue #16)

The documented path to DoD "any scenario can be added". Field reference:
`docs/scenario-format.md`. Proven by `run.dag-failure.002`, built following
only these steps.

## Steps

1. **Copy the template.**
   `mkdir scenarios/<id>`; copy `scenarios/_template/scenario.yaml` to
   `scenarios/<id>.yaml`; copy `_template/solution.sh`, `_template/test.sh`
   into `scenarios/<id>/`; write `scenarios/<id>/fault-inject.sh` mirroring
   `run.dag-failure.001/fault-inject.sh` (compose-exec state writes + printed
   failure signature + `[seed]` arg, default 7).
2. **Fill `<M,E,T,D>`.** Replace every `<FILL>`; `class` must be one of the
   10 RUN classes; `autonomy` and `safety` verbs must match the class row in
   `specs/09-task-classes.md`. Ground truth needs 2+ entities, a 4-link
   `propagation_chain`, and 2 fix variants.
3. **Fault script.** Same shape as step 1: deterministic ids derived from
   seed (`application_$((1690000000 + SEED))_0001` pattern); same seed must
   reproduce the same signature.
4. **Oracle + probes.** Fill the STATE LAYOUT section of `solution.sh`
   (idempotent, recreates fixed state from clean env, writes agent-style
   `result.json`); set the entity id in `test.sh`. Both probe types are
   mandatory: `probe_diagnosis_exact` + `probe_mitigation_statecheck`.
   Canary strings ship with the template — keep them.
5. **Guardrail verbs.** `safety.allowed_verbs/gated_verbs`,
   `abstain_allowed: true`, fail-closed `blast_radius` (checked by
   `runner/safety.sh`).
6. **Validate.** `sh bin/scenario validate scenarios/<id>.yaml`.
7. **Oracle-5x.** `sh ci/oracle-5x.sh <id>` — 5/5 green from clean env.
   Prove FAIL_TO_PASS first: `test.sh` on an empty `$STATE_DIR` must fail.
8. **Mark open vs hidden.** Default is **open** (tracked, tag `open-set`).
   Hidden-split variants stay **outside the repo** — never commit `hidden/`;
   `ci/check-hidden-split.sh` enforces both halves.
9. **Docs.** Add the scenario to the matrix in `docs/coverage.md`
   (`docs/test-docs.sh` fails if you forget).
10. **PR.** CI runs validate, oracle-5x (sample + your scenario),
    contamination (canary/seed/hidden/trials), secrets, append-only.

## Reviewer checklist (all checkable)

- [ ] `bin/scenario validate` green
- [ ] `ci/oracle-5x.sh` 5/5 log attached
- [ ] probes FAIL_TO_PASS demonstrated (red on pre-fix, green post-fix)
- [ ] canary present, seed pinned, `hidden/` absent
- [ ] `docs/coverage.md` row added

## Self-hosted only (v1)

There is no hosted registration/auth flow in v1 — no ITBench GitHub-App
equivalent. Contributors run the self-hosted flow above (clone → template
→ validate → oracle-5x → PR). Hosted registration is explicitly deferred
to post-v1.
