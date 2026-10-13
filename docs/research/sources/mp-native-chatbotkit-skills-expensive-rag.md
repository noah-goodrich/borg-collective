# Source: ChatBotKit, Skills: an expensive form of RAG

**Full citation:** Petkov, Petko D. "Skills: an expensive form of RAG." ChatBotKit reflections, 2026-04-23. https://chatbotkit.com/reflections/skills-an-an-expensive-form-of-rag
**URL:** https://chatbotkit.com/reflections/skills-an-an-expensive-form-of-rag
**Date accessed:** 2026-10-13
**Evidence level:** 7 (expert opinion piece from a vendor founder)
**Research topic area:** Contrarian view on the skills paradigm itself

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|---------------|
| 1 | Authority | 5/10 | Vendor founder, CISO |
| 2 | Evidence Quality | 3/10 | Argument, no data |
| 3 | Currency | 9/10 | April 2026 |
| 4 | Intent | 4/10 | Sells competing platform |
| 5 | Bias & Objectivity | 4/10 | Strong thesis |
| 6 | Logic & Coherence | 7/10 | Token-cost reasoning |
| 7 | Corroboration | 6/10 | Shadowing paper partly agrees |
| 8 | Intellectual Honesty | 5/10 | One-sided |
| 9 | Specificity | 5/10 | Conceptual |
| 10 | Relevance | 6/10 | Applies to any skill pack |

- Authority: the author builds a competing agent platform.
- Evidence Quality: conceptual argument, no measurements.
- Currency: 2026-04-23.
- Intent: ChatBotKit sells an agent platform, which is an interest in disparaging skills as a design.
- Bias: I disagree that skills have no merit, so I scored dims 5, 6, and 8 more generously.
- Logic: preloading every name and description is a real token cost.
- Corroboration: the ICML skill-shadowing paper finds selection failure rather than context cost to be the main problem, which partly contradicts the cost argument.
- Honesty: one-sided; does not address progressive disclosure savings.
- Specificity: conceptual, with no numbers.
- Relevance: applies to skill packs in general; contrarian anchor.

**Score band:** borderline

## Bias Guard Check

- [ ] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [x] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [ ] Neutral / no strong reaction

## Key Findings

- Thesis: skills, MCP tools, and RAG all solve selective retrieval, and skills have the worst context economics.
- Mechanism claimed: every skill's name and description is preloaded, then the body is loaded on selection, so you pay twice.
- Predicts skills-first architecture will suit small models poorly.
- Counterpoint from evidence elsewhere: the Claude docs say context overhead is mitigated by progressive disclosure and user-only skills hide from selection, and the ICML paper finds context overhead small.
- Value to this track: a contrarian anchor; Matt's `disable-model-invocation` split answers the cost objection directly.

## Verified Quote(s)

**Location reference:** Section arguing skills as cache-augmented generation (body, central argument paragraph).

> You pre-commit tokens to an index you may or may not use, and then pay again to pull the content.

**Access status:** live

## Inclusion Decision

**Decision:** Supporting
**Rationale:** Borderline on credibility; included as the required Contrarian perspective, labeled as vendor opinion.

**Redundancy check:** Unique contrarian voice on the paradigm.

**Perspective category:** Contrarian
