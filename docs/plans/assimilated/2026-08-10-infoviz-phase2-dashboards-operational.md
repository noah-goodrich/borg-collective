# Directive: Infoviz Phase 2 — Dashboards & Operational UI (Track 1)
*Filed: 2026-08-10*

Filed as a directive rather than `PROJECT_PLAN.md` because Plan 1 (Story-Lens P1 fix + branch consolidation)
still occupies that slot pending the merge of PR #104. Independent work — no parent plan.

## Objective
Run Phase 2 of the infoviz learning program over Track 1 (Dashboards & operational/monitoring UI), the
curriculum's own designated "read first" track, and append its evidence-traced house rules (D-prefix) to
`docs/infoviz/playbook.md`. Close the phase with an empirical test against a real in-house operational artifact
plus a comprehension check, per the program mandate.

## Why this track, and why now
`03-design-principles-playbook-additions.md:92` names Track 1 as the natural Phase 2 "regardless of this
sub-project's sequencing choice, since it's the applied layer these principles feed into." Phase 1 derived how a
single quantity should be encoded; Track 1 governs the display those encodings live on.

## Evidence-base warning (drives the criteria below)
The six Track 1 source cards carry evidence levels **7, 4, 5, 1, 8, 7**. Exactly one is Level 1 (Tariq et al.,
ACM CSUR 2025). The track's foundational text — Few's *Information Dashboard Design* — is Level 7 practitioner
opinion, and the contrarian close (Brownlow) is Level 8 anecdote. This is the weakest evidence base in the
corpus, and the phase's main intellectual risk is laundering strong opinion into house rules.

## Acceptance Criteria
- [x] C1 — Four research documents exist under `docs/infoviz/research/2026-08-10-dashboards-operational/`,
      matching Phase 1's shape: `01-findings-synthesis.md`, `02-eli10-brief.md`,
      `03-design-principles-playbook-additions.md`, `04-empirical-test.md`.
  - Verify: `ls docs/infoviz/research/2026-08-10-dashboards-operational/` lists all four.
- [x] C2 — D-rules are appended to `docs/infoviz/playbook.md` under a Phase 2 heading, each stating house rule,
      evidence, and confidence/caveat in the same shape as P1-P7. Phase 1's P-rules are untouched.
  - Verify: `grep -c '^\*\*D[0-9]' docs/infoviz/playbook.md` returns the rule count;
    `git diff main -- docs/infoviz/playbook.md` shows only additions.
- [x] C3 — Every D-rule names its evidence level explicitly. No rule derived solely from a Level 7/8 source is
      stated at high confidence.
  - Verify: read each rule's Confidence line; each cites at least one source and its level.
- [x] C4 — The empirical test applies the D-rules to borg's own alert/hook layer (primary specimen) and
      `borg ls` (secondary), and runs a comprehension check. Findings are derived from the rules, not
      reverse-engineered to fit a known conclusion.
  - Verify: `04-empirical-test.md` has a rule-by-rule critique section and a stated verdict per specimen.
- [x] C5 — Open items for Phase 3+ are recorded, including anything the phase could not verify first-hand.
  - Verify: `grep -n -i 'open items' docs/infoviz/research/2026-08-10-dashboards-operational/03-*.md`
- [x] C6 — Regression: no code touched, bats suite unaffected.
  - Verify: `git diff --name-only main` shows only files under `docs/`.

## Scope Boundaries
- NOT changing any hook behavior. The empirical test diagnoses the alert layer; remediation is a separate plan.
- NOT writing new source cards. Phase 0 already produced all six Track 1 cards; this phase reads deeper and
  derives, it does not re-appraise.
- NOT reading Few's book cover-to-cover. Chapter 1 (the single-screen definition and the 13 mistakes) is the
  load-bearing part per the curriculum; anything beyond it that gets cited must be marked secondhand.
- If done early: ship, don't expand.

## Ship Definition
Four documents committed, D-rules appended to the playbook, PR opened against main, CI green.

SHIPPED 2026-08-11 in commit 2242ddd (PR #112). C6 partial by packaging only — the infoviz deliverables are
docs-only, but PR #112 squash-merged unrelated CLI work (borg.zsh, lib/registry.zsh, install.sh,
tests/cli_smoke.bats) alongside them. Remediation of the empirical test's findings was correctly deferred to
the separate 2026-08-11-attention-routing directive. The secondary specimen `borg ls` no longer exists under
that name — the aliases were removed 2026-08-10 and the command was ported to borg_core in PR #143; the
critique stands as a historical record of that display.

## Timeline
Target: this session. Estimated effort: the largest single item in the session — Phase 1's findings synthesis
alone ran 230+ lines and this phase produces four documents at comparable depth.

## Risks
- **Motivated reasoning on the specimen.** The alert-layer defect was noticed before the rules were derived
  (the tool-count nudge fired twice during the session that planned this). The critique must follow from the
  D-rules; where a finding predates them, say so.
- **Level-7 laundering.** Few's doctrine is the track's spine and is expert opinion. Rules derived from it must
  say so rather than inheriting borrowed authority from the one Level 1 source in the set.
- **Few's book is a scanned third-party PDF.** Provenance is a personal temp directory. Anything cited from
  beyond Chapter 1's well-corroborated claims should be treated as secondhand.
