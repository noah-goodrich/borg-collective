# Source: "More Skills, Worse Agents?" (ICML 2026 workshop)

**Full citation:** Song, Hongwen; Wei, Song. "More Skills, Worse Agents? Skill Shadowing Degrades Performance When Expanding Skill Libraries." ICML 2026 workshop poster ("Failure Modes in Agentic AI"); also presented at the ACM CAIS 2026 Agent Skills workshop per a secondary summary. https://icml.cc/virtual/2026/77891. Fetched 2026-10-13.
**URL:** https://icml.cc/virtual/2026/77891
**Date accessed:** 2026-10-13
**Evidence level:** 3 (quantitative empirical study, workshop-level, not full peer review)
**Research topic area:** Skill-library scaling risk (relevant to installing a 20-skill catalog beside native and borg skills)

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|---------------|
| 1 | Authority | 7/10 | Workshop paper, industry lab |
| 2 | Evidence Quality | 7/10 | Controlled library scaling |
| 3 | Currency | 10/10 | 2026 |
| 4 | Intent | 9/10 | Research |
| 5 | Bias & Objectivity | 8/10 | Decomposes two effects |
| 6 | Logic & Coherence | 8/10 | Shadowing vs overhead |
| 7 | Corroboration | 7/10 | arXiv capacity result agrees |
| 8 | Intellectual Honesty | 8/10 | Reports upper bounds |
| 9 | Specificity | 8/10 | 202 skills, up to 21% drop |
| 10 | Relevance | 8/10 | Bears on skill sprawl |

- Authority: workshop poster; the secondary summary names Databricks affiliation but the ICML page did not, so treat affiliation as unverified.
- Evidence Quality: it measures pass-rate while scaling from a small helpful set to 202 skills and separates two causes.
- Currency: 2026.
- Intent: academic inquiry.
- Bias: finds that context overhead is small and statistically indistinguishable from zero, which cuts against the common "context bloat" explanation.
- Logic: shadowing (wrong skill picked) versus overhead (extra context hurts execution).
- Corroboration: a separate arXiv paper (Li, 2026) finds accuracy stable up to a critical library size and then a sharp drop, driven by semantic confusability.
- Honesty: presents estimates and upper bounds.
- Specificity: up to 21% performance drop at 202 skills, per the page abstract.
- Relevance: limited transfer, since the benchmark is not Claude Code with a human-curated catalog.

**Score band:** keep

## Bias Guard Check

- [ ] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [x] Neutral / no strong reaction

## Key Findings

- The study reports that performance can drop by up to 21% when a library grows from a small helpful set to 202 skills.
- Its decomposition says skill selection failure (shadowing), not enlarged context, is the primary bottleneck.
- Implication for catalogs: overlapping skills with similar descriptions (for example Matt's `/code-review` and Claude Code's native `/code-review`, or a borg review skill beside both) are the confusable pairs that cause shadowing.
- Matt's user-invoked versus model-invoked split mitigates this by hiding user-invoked skills from automatic selection, which is a design choice aligned with the finding even though the paper does not test it.
- Caveat: workshop-level, not directly tested on Claude Code or on a catalog of this size (about 20 active skills).

## Verified Quote(s)

**Location reference:** Poster abstract on the ICML virtual page, final sentence.

> the skill selection failure, not the enlarged context, is the primary bottleneck when expanding the skill libraries

**Access status:** live

## Inclusion Decision

**Decision:** Supporting
**Rationale:** The only academic quantitative evidence on skill-library growth; included as a caution with the transfer caveat.

**Redundancy check:** Paired with the arXiv scaling paper, which gives a second independent result.

**Perspective category:** Academic
