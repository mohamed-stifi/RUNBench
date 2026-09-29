# Oracle template (Issue #05)

Every scenario ships `solution.sh` + `test.sh` in the same shape so the evaluator
can score execution-based results outside the agent container (`specs/07-evaluator.md`).

## Layout

```
scenarios/<scenario-id>/
  solution.sh   # reference fix; idempotent; recreates fixed state from clean env
  test.sh       # oracle probes; sources ../_template/lib/probes.sh
  fault-inject.sh  # (Issue #04) seeds the faulted pre-fix state
```

`scenarios/_template/` holds the canonical copies: `solution.sh`, `test.sh`,
and `lib/probes.sh` (shared probe functions, POSIX sh + grep only).

## Required probe types (every new scenario MUST have both)

| Probe | Function | What it checks |
|---|---|---|
| diagnosis exact-match | `probe_diagnosis_exact <result.json> <entity>` | agent's `diagnosis` equals the ground-truth entity id (harness contract field) |
| mitigation state-check | `probe_mitigation_statecheck <state-file> <expected>` | post-fix system state (e.g. DAG `success`) |

Custom probes may be added, but these two are mandatory.

## Oracle gate (per scenario, before any agent work)

1. `test.sh` FAILS on the faulted pre-fix state (true FAIL_TO_PASS).
2. `solution.sh && test.sh` passes 5 consecutive runs from a clean env
   (`rm -rf "$STATE_DIR"` between runs; no flakes allowed).
3. New scenarios copy `_template/{solution.sh,test.sh}`, fill in the marked
   sections, and point the scenario YAML `oracle:` block at the real paths
   (keep `status: stub` until `fault-inject.sh` lands in Issue #04).
