# Source: BestHub: Exploring /grill-with-docs, a New Rival to Superpowers

**Full citation:** Unattributed article. "Exploring /grill-with-docs: A New Rival to Superpowers in AI Coding Skills." BestHub, published 2026-07-07. https://www.besthub.dev/articles/exploring-grill-with-docs-a-new-rival-to-superpowers-in-ai-coding-skills-ac31c21fdc7d. Accessed 2026-10-13.
**URL:** https://www.besthub.dev/articles/exploring-grill-with-docs-a-new-rival-to-superpowers-in-ai-coding-skills-ac31c21fdc7d
**Date accessed:** 2026-10-13
**Evidence level:** 8 (anecdotal single-project impressions)
**Research topic area:** PM / planning: how Matt Pocock structures work for agents (PRD/spec, grilling, tracer-bullet tickets, HITL/AFK labels, triage, TDD loop) and how it relates to established methods and to borg

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|---------------|
| 1 | Authority | 3/10 | Aggregator article, no verifiable author credentials. |
| 2 | Evidence Quality | 3/10 | Single iOS project, no head-to-head comparison. |
| 3 | Currency | 10/10 | July 2026. |
| 4 | Intent | 4/10 | Content-aggregator traffic piece. |
| 5 | Bias & Objectivity | 6/10 | Balanced and non-adversarial. |
| 6 | Logic & Coherence | 6/10 | Argument (light touch versus strict hooks) is coherent. |
| 7 | Corroboration | 5/10 | Echoed by the Addy Osmani comparison page. |
| 8 | Intellectual Honesty | 7/10 | States its evidence is one project and that it plans a swap test. |
| 9 | Specificity | 6/10 | Gives counts (14 skills, 371-line TDD skill). |
| 10 | Relevance | 7/10 | Contrasts Matt's manual-invocation design with a hook-forced pipeline. |

**Score band:** reject (weighted average about 4.90). Cut: scores in the reject band, kept on disk only as a documented exclusion.

## Bias Guard Check

- [ ] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [x] Neutral / no strong reaction

## Key Findings

- Matt's skills assume the model is usually correct and intervene only at critical anchors; Superpowers assumes the model will slack and forces skill execution via hooks.
- Matt's skills are mostly user-invoked, which the author sees as keeping the developer in control.
- Evidence is one author's iOS project; no delivery-quality comparison.

## Verified Quote(s)

**Location reference:** Section on design philosophy, first bullet (comparison of Matt's skills with Superpowers).

> Matt's skills assume the model is usually correct and only intervene at critical anchors.

**Access status:** live

## Inclusion Decision

**Decision:** Excluded
**Rationale:** Scores in the reject band (unattributed, single-project, aggregator); not relied on in findings. Kept as a documented cut. The same invoke-by-hand point is better sourced from the repo's own disable-model-invocation flags and the Addy Osmani comparison.

**Redundancy check:** Dominated by the Addy Osmani comparison and the repo files.

**Perspective category:** Boots-on-the-ground
