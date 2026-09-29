# CI gates (Issue #15)

Workflow: [`.github/workflows/ci.yml`](../.github/workflows/ci.yml). PRs
touching benchmark material trigger all gates as independent jobs; pushes to
main re-prove them on the sample scenario.

| Job | Gate script | Blocks |
|---|---|---|
| validate | `schemas/validate.py` over `scenarios/*.yaml` | invalid scenario merge |
| oracle-5x | `ci/oracle-5x.sh` (sample + changed scenarios, clean env each run) | flaky oracle merge (logs attached) |
| redaction | `runner/test-safety.sh` (Issue #09 trace-redaction check) | secret-leaking trace merge |
| secrets | gitleaks binary (pinned v8.30.1) | leaked-secret merge |
| contamination | `check-canary.sh` + `check-seed-pinning.sh` + `check-hidden-split.sh` + `check-trials.sh` | unmarked/unpinned/leaked/n<3 merge |
| append-only | `ci/check-append-only.sh` (releases immutable, run_ids only grow) | history rewrite merge |

Contamination policy: every oracle script carries
`RUNBENCH-CANARY 7f3a9c1e-...` (Big-Bench style, crawl-excludable);
`hidden/` is never tracked and public images never COPY oracle material
(SWE-bench-Pro lesson); `environment.seed` pinned per scenario; new
scenarios need a multiple-split board entry with trials≥3 (paper §4.4).

Flake quarantine: `leaderboard/quarantine.json` lists flaky scenarios with
reason+log. Quarantine blocks `release.sh` (release gate) but NOT merge —
board builds stay green so diagnosis continues.

Local proof: `sh ci/test-gates.sh` builds deliberately broken fixtures in
TMPDIR (never committed) and asserts each gate fails independently with a
`GATE-FAIL` message, then asserts green main. Must stay 22/22. Note: the
fake-secret fixture must look random — gitleaks allowlists obvious example
keys (verified: `AKIAIOSFODNN7EXAMPLE` and sequential `ghp_abc…` pass, a
random `ghp_<hex36>` fails).
