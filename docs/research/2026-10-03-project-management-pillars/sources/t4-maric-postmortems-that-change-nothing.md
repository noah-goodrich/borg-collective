# Source: Maric (2026) — Incident post-mortems that change nothing

**Full citation:** Igor Maric. "Incident post-mortems that change nothing: the blameless accountability ritual."
odd.fyi (imTheOdd0ne), 14 April 2026.
**URL:** https://odd.fyi/blog/article/incident-post-mortems-that-change-nothing-the-ritual-of-blameless-accountability/
**Date accessed:** 2026-10-03
**Evidence level:** 7
**Research topic area:** T4 learning/adaptation — post-mortems that do not prevent recurrence (falsification)

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|---------------|
| 1 | Authority | 3/10 | Individual engineering blogger; no verified research credentials. |
| 2 | Evidence Quality | 3/10 | Leans on vendor and survey statistics (Dimensional Research 2022, PagerDuty 2024) that are secondhand and not checked here. |
| 3 | Currency | 10/10 | April 2026. |
| 4 | Intent | 6/10 | Opinion essay; personal brand blog, no product sale. |
| 5 | Bias & Objectivity | 5/10 | Strong thesis; selective vendor stats. |
| 6 | Logic & Coherence | 6/10 | Plausible chain from documentation to ritual, but the headline "half of incidents are repeats" is a proxy figure. |
| 7 | Corroboration | 5/10 | Matches Allspaw's argument; the repeat-incident statistic is not independently verified in this pass. |
| 8 | Intellectual Honesty | 7/10 | Openly says no rigorous large-sample study of action-item completion exists. |
| 9 | Specificity | 7/10 | Named cases and numbered references. |
| 10 | Relevance | 7/10 | Directly the "do post-mortems change anything" question, software context. |

**Score band:** borderline (weighted average about 5.1)

## Bias Guard Check

- [x] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [ ] Neutral / no strong reaction

## Key Findings

- Claims post-mortems are near-universal but follow-through is weak; the best proxy offered is a survey figure that 48%
  of production incidents are straightforward and repetitive (secondhand; unverified here).
- Explicitly concedes there is no rigorous, large-sample study of post-mortem action-item completion — an evidence gap,
  not a finding that post-mortems fail.
- Argues the document is only evidence that analysis happened; learning shows up later in architecture, priorities and
  budgets.
- Treat as a hypothesis generator for "does the loop close": track what changed, not whether a write-up exists.

## Verified Quote(s)

**Location reference:** Quote 1: Section "The gap between writing and doing", paragraph 2 (counting body paragraphs
after the heading), second sentence. Quote 2: the "TL;DR" summary paragraph at the top of the page (before the Knight
Capital opening and the first section heading), sixth of its seven sentences.

> The industry lacks a single rigorous, large-sample study measuring post-mortem action item completion rates — which is itself telling.

> The document is only evidence that analysis happened.

**Access status:** live

## Inclusion Decision

**Decision:** Supporting
**Rationale:** Borderline band kept by documented reason: the only 2026 contrarian source that names the evidence gap
honestly; use for the gap, not for the repeat-incident percentage.

**Redundancy check:** Overlaps Allspaw; adds the explicit "no rigorous completion-rate study" statement.

**Perspective category:** Contrarian

Card revised: 2026-10-03 (location audit before re-verification)
