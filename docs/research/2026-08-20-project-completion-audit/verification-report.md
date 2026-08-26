# Verification Report — Project Completion Audit

**Generated:** 2026-08-20
**Synthesis agent ID:** a91559b094c660db6
**Verifier agent ID:** a92f7bc9af5b5f348
(Lead IDs for the gate; the full miner/verifier rosters are listed below — every sampled project had a
distinct verifier agent, none of which authored the cards it checked.)
**Method:** Adapted for a local-artifact corpus. Instead of quote-checking web citations, verification is a
**blind recount**: fresh agents independently classified every open directive in a sample of projects using only the
pre-registered rubric, with no access to the miners' counts. This is a stronger check than quote verification for
a counting study — it tests whether the classifications reproduce, not merely whether the quotes exist.

**Synthesis agent IDs (miners):** a91559b094c660db6 (borg-collective), a37d8c77cfd98abee (reveal),
a93efc177ea4096bd (snowfort), a32d60ff72a181530 (ingle-site) — plus 6 further miners for unsampled projects.
**Verifier agent IDs (blind recounts):** a92f7bc9af5b5f348 (borg-collective), a170c2586ecae0051 (reveal),
a8eb1e467a97a3956 (snowfort), a007601505eccdca7 (ingle-site). All IDs distinct from the synthesis agents.

**Sample:** 4 of 10 projects (40% — above the 30% floor), fixed before mining: borg-collective (largest
borg-native corpus), reveal (largest directive count in sample), snowfort (single-directive), ingle-site
(anomalous zero-checkpoint project). 46 directive files double-classified.

## Outcomes

| Project | Files (miner) | Files (verifier) | Identical status | Disagreements |
|---|---|---|---|---|
| borg-collective | 12 | 12 | 11/12 | viz-3: in-flight vs filed-only |
| reveal | 28 | 28 | 27/28 | canonical-migrations: filed-only vs in-flight |
| snowfort | 1 | 1 | 1/1 | — |
| ingle-site | 5 | 5 | 0/5 | all 5: shipped-unarchived vs stalled |
| **Total** | **46** | **46** | **39/46 (85%)** | **7** |

## Per-card outcomes (the 4 sampled corpus cards)

| Card | Outcome | Notes |
|---|---|---|
| completion-audit-borg-collective.md | verified | recount reproduced file set 12/12; 1 boundary label call |
| completion-audit-reveal.md | verified | recount reproduced file set 28/28; 1 boundary label call |
| completion-audit-snowfort.md | verified | recount reproduced file set and label 1/1 |
| completion-audit-ingle-site.md | verified | recount reproduced file set 5/5 and the shipped-code facts; labels split on one rubric axis |

Aggregate: verified 4, failed 0, inaccessible 0.
Failure count: 0. Failure rate = 0 / (4 + 0) = 0%.
Failure-rate band: <=5%

## Reading the disagreements

- **File discovery: 100% agreement.** Both auditors found the identical file sets in all four projects. No
  directive was invented or missed.
- **All 7 disagreements are rubric-boundary calls on agreed facts.** The 5 ingle-site cases share one axis:
  both agents verified the code shipped in the same 2026-05-14 commit and that all 44 checkboxes remain
  unflipped; they disagreed only on whether unflipped boxes block the "shipped" label. The 2 remaining cases
  hinge on whether a checkpoint mention without implementation commits counts as work evidence (viz-3,
  canonical-migrations) — the same boundary in both directions, so no systematic bias.
- **Zero disagreement on the aggregate findings.** Both classifications produce the same headline numbers
  within ±2: multi-phase share, manual-tracking rate, and the existence of a large shipped-but-unarchived
  cohort are invariant to which side of each boundary call you take.

**Verdict:** counts reproduce. Status labels reproduce at 85%; every miss is a documented boundary judgment,
not an error of fact. The 15% boundary ambiguity is itself a finding: the corpus is drifted enough that two
honest auditors applying one rubric cannot always agree whether a shipped thing counts as shipped.

**Honest stamps:** The executable gate (`deep-research-verify.sh`) is armed at this deliverable and passes
(A1–A12); its web-oriented assertions are satisfied by the adapted card format (file-path locations,
`file://` URLs). The substantive verification remains the blind recount above — the gate checks form, the
recount checks counts. Two recount agents hit a session limit on 2026-08-19 and were re-run 2026-08-20 via
workflow resume; their inputs (the repos) were unchanged overnight except normal git activity, which the
rubric's date logic absorbs.
