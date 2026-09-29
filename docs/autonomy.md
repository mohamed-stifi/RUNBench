# Autonomy layers L0–L5 (Issue #16)

Thin mirror of [`../specs/03-autonomy-layers.md`](../specs/03-autonomy-layers.md)
(source of truth). L0 manual → L5 full autonomy. Enforcement summary
(`runner/safety.sh` is the executable version):

| Layer | Agent may | Gate |
|---|---|---|
| L1 | read-only obs | writes rejected |
| L2+ | allowed verbs | `safety.allowed_verbs` per scenario |
| L2+ | gated verbs | policy check per verb |
| < L4 | dry-run only for irreversible ops | approval stub at L4+ |
| any | abstain when evidence inconclusive | `abstained` status, never forced |

Every scenario declares `autonomy: {start, target}` and
`safety: {allowed_verbs, gated_verbs, abstain_allowed}` plus a
`blast_radius` list (fail-closed). Each task class has its own start/target
row — see `docs/coverage.md`.
