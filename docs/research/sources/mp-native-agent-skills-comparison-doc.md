# Source: agent-skills project comparison doc (agent-skills vs Superpowers vs Pocock)

**Full citation:** agent-skills project (addyosmani/agent-skills repository). "Comparison" docs page. https://github.com/addyosmani/agent-skills/blob/main/docs/comparison.md. Page is unsigned; author of the page not stated. Fetched 2026-10-13.
**URL:** https://raw.githubusercontent.com/addyosmani/agent-skills/main/docs/comparison.md
**Date accessed:** 2026-10-13
**Evidence level:** 7 (peer-framework author opinion)
**Research topic area:** Practitioner comparison of Matt's skills with peer frameworks

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|---------------|
| 1 | Authority | 5/10 | Rival project's maintainers |
| 2 | Evidence Quality | 5/10 | Structured but unmeasured |
| 3 | Currency | 8/10 | 2026 |
| 4 | Intent | 4/10 | Promotes its own project |
| 5 | Bias & Objectivity | 6/10 | Self-declared fairness |
| 6 | Logic & Coherence | 8/10 | Dimension table |
| 7 | Corroboration | 6/10 | Matches other reviews |
| 8 | Intellectual Honesty | 7/10 | "fair than flattering" |
| 9 | Specificity | 8/10 | Lifecycle, evals, governance |
| 10 | Relevance | 8/10 | Direct peer comparison |

- Authority: written by a competing catalog's maintainers; the page byline is not stated.
- Evidence Quality: dimension-by-dimension tables (core idea, catalog, lifecycle, quality measurement, tooling reach, governance) without methodology.
- Currency: describes the 2026 catalogs, including the in-progress `wayfinder`.
- Intent: it exists inside a competing project's docs; the author's own project is rated best on lifecycle and evals.
- Bias: states "We would rather be fair than flattering" and gives Matt's skills credit for requirements grilling.
- Logic: consistent comparison axes.
- Corroboration: the besthub review makes a similar point about Superpowers's enforcement versus Matt's manual style.
- Honesty: lists the weaknesses of Matt's catalog (no evals, thin after Build, Claude Code first in practice).
- Specificity: names the user-invoked versus model-invoked split.
- Relevance: the most structured peer comparison found.

**Score band:** borderline

## Bias Guard Check

- [ ] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [x] Neutral / no strong reaction

## Key Findings

- Matt's skills are described as a "sharp, opinionated Claude Code toolkit distilled from one expert's daily workflow", with the center of gravity in grilling, not TDD.
- Listed trade-offs: Claude Code first in practice (other agents surface reliability rough edges), no in-repo evals, thin lifecycle coverage past Build, and personal-setup coupling.
- Peers differ on enforcement: Superpowers uses hooks and strict pipelines; Matt's skills stay mostly manual.
- Governance: one author who merges their own changes, developed in public; the page notes a drift toward multi-session orchestration through issue trackers (`wayfinder`).
- Conclusion offered: none is best in the abstract; pick per task.

## Verified Quote(s)

**Location reference:** Section on Matt Pocock's skills, first sentences of the first and last paragraphs; "Quality measurement" row of the comparison table.

> The center of gravity is not TDD, it is **grilling**

> there are no in-repo evals to catch regressions

> We would rather be fair than flattering.

**Access status:** live

## Inclusion Decision

**Decision:** Supporting
**Rationale:** Borderline for intent; included because it is the only structured peer-framework comparison and it is candid about gaps.

**Redundancy check:** Overlaps besthub on Superpowers contrast; adds the evals, lifecycle, and governance dimensions.

**Perspective category:** Practitioner
