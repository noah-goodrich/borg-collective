# Source: Addy Osmani agent-skills: "Honest positioning" comparison page

**Full citation:** Addy Osmani and contributors. "How agent-skills compares." skills.addy.ie. 2026 (undated page, read 2026-10-13).
**URL:** https://skills.addy.ie/compare/
**Date accessed:** 2026-10-13
**Evidence level:** 7 (Expert opinion; competitor-authored comparison)
**Research topic area:** Reception of Matt Pocock skills (mp-reception)

## Credibility Scores

| # | Dimension | Score | Note |
|---|-----------|-------|------|
| 1 | Authority | 6/10 | well-known engineer |
| 2 | Evidence Quality | 5/10 | feature table, no tests |
| 3 | Currency | 8/10 | undated 2026 |
| 4 | Intent | 3/10 | promotes own repo |
| 5 | Bias & Objectivity | 5/10 | self-interested |
| 6 | Logic & Coherence | 7/10 | coherent |
| 7 | Corroboration | 6/10 | agrees w/ others |
| 8 | Intellectual Honesty | 6/10 | calls itself honest |
| 9 | Specificity | 7/10 | lists mechanisms |
| 10 | Relevance | 8/10 | direct comparison |

Justifications (one line per dimension, same order):

1. Authority: Addy Osmani is a widely recognized engineering author, but he writes here as a competing maintainer.
2. Evidence Quality: Feature comparison with a cited controlled experiment by a third party (Om Mishra), but that experiment excludes Pocock.
3. Currency: Undated, but covers 2026 versions and star-count caveats.
4. Intent: Page exists to position his own agent-skills library against the other two.
5. Bias & Objectivity: Positions his own pack as covering more of the lifecycle; the Pocock summary is polite but incomplete.
6. Logic & Coherence: The table's organizing logic is consistent.
7. Corroboration: Pocock's no-in-repo-evals trait matches nocoders; "Claude-Code-first" is contradicted by the repo README's multi-harness claim.
8. Intellectual Honesty: Declares its stance ("honest map") and drops star counts for being cited inconsistently.
9. Specificity: Table lists catalog size, mechanisms and evals per library.
10. Relevance: Directly on the Matt-vs-others comparison question, though from an interested party.

**Score band:** borderline

## Bias Guard Check

- [ ] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [x] Neutral / no strong reaction

Note: author has a commercial/reputational interest in agent-skills; dims 5 and 4 scored hard for that reason.

## Key Findings

- A competing maintainer describes Pocock's skills as "a sharp, opinionated daily toolkit with a signature grill me loop", strongest at requirements and TDD.
- Flags that Pocock's repo ships no in-repo skill evals while agent-skills ships a three-tier eval framework in CI.
- Calls the pack "Claude-Code-first in practice, with thinner coverage past Build" (no CI/CD, observability, security lifecycle).
- Reports a controlled Superpowers-vs-agent-skills experiment (same model, repo, prompt; ~8 vs ~12 minutes, 7 vs 5 validation passes) that did not include Pocock.
- Deliberately omits star counts because they are "cited wildly differently and change weekly".

## Verified Quote(s)

**Location reference:** Paragraph under "At a glance" table (star counts); "The other two, in their own terms" entry for Matt Pocock's skills; "TL;DR" paragraph.

> We deliberately leave out star counts and adoption figures - they’re cited wildly differently and change weekly.

> Authentic and sharp; Claude-Code-first in practice, with thinner coverage past Build and no in-repo evals.

> Matt Pocock’s skills are a sharp, opinionated daily toolkit with a signature “grill me” loop.

**Access status:** live

## Inclusion Decision

**Decision:** Supporting
**Rationale:** Keep-band-adjacent but conflicted source: used for the "no in-repo evals" and "Claude-Code-first" characterisations, each also supported by an independent card.

**Redundancy check:** The "no evals" point is also in nocoders; the multi-harness contradiction with the README is unique here.

**Perspective category:** Practitioner
