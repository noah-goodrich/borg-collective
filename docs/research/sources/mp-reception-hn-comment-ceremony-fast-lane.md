# Source: HN comment (cg-enterprise): ceremony cost and a fast/full lane over Pocock-style flows

**Full citation:** cg-enterprise. Comment on "OpenSpec - A lightweight and configurable AI spec framework". news.ycombinator.com. 2026-09-17.
**URL:** https://news.ycombinator.com/item?id=49737218
**Date accessed:** 2026-10-13
**Evidence level:** 8 (Anecdotal / practitioner experience)
**Research topic area:** Reception of Matt Pocock skills (mp-reception)

## Credibility Scores

| # | Dimension | Score | Note |
|---|-----------|-------|------|
| 1 | Authority | 3/10 | anonymous, specific |
| 2 | Evidence Quality | 4/10 | detailed first-hand |
| 3 | Currency | 10/10 | 4 weeks old |
| 4 | Intent | 5/10 | promotes own fork |
| 5 | Bias & Objectivity | 6/10 | pragmatic |
| 6 | Logic & Coherence | 7/10 | coherent |
| 7 | Corroboration | 5/10 | aligned w/ borg need |
| 8 | Intellectual Honesty | 6/10 | names own omissions |
| 9 | Specificity | 6/10 | 5 specific gaps |
| 10 | Relevance | 8/10 | close to borg's design |

Justifications (one line per dimension, same order):

1. Authority: Anonymous HN user with a described, custom SDLC workflow.
2. Evidence Quality: First-hand list of five gaps, no metrics.
3. Currency: Posted 2026-09-17.
4. Intent: Mentions and links their own fork, so there is a mild promotional interest.
5. Bias & Objectivity: Uses Pocock's skills and Superpowers and still lists omissions, which is balanced.
6. Logic & Coherence: Gaps follow from the experience described.
7. Corroboration: The spectrum-of-frameworks framing is echoed by a sibling comment, though the gap list itself is unique.
8. Intellectual Honesty: Acknowledges they built their own flow because existing frameworks left gaps.
9. Specificity: Gives five concrete gaps: ADR staleness, review loop, deferral tracking, governance, ceremony by size.
10. Relevance: Most of the gaps are the same ones a queen/drone workflow aims to solve.

**Score band:** borderline

## Bias Guard Check

- [ ] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [x] Neutral / no strong reaction

## Key Findings

- A user of Superpowers and Pocock's skills for spec-driven development still built custom workflow management because existing frameworks omit artifact-staleness tracking, multi-model review, deferral tracking and governance gates.
- Pocock-style ceremony can be disproportionate: a 100+ line spec for a 10-line change led them to a "full lane" vs "fast lane" split using the native plan feature for small changes.
- A sibling commenter frames the field as a spectrum from fluid workflows (OpenSpec) to "up-front alignment and control" (Pocock).
- Shows demand for a layer above the skills (governance, tracking), which the skills themselves do not provide.

## Verified Quote(s)

**Location reference:** Comment by cg-enterprise on HN item 49734264 (OpenSpec), intro paragraph and list item 5 "Ceremony based on context"; comment id 49737218.

> some of the ceremony would get in the way at some points (like producing a 100+ loc spec for 10loc change)

> (for SDD I prefer to use Superpowers and/or Matt Pocock's skills)

**Access status:** live

## Inclusion Decision

**Decision:** Supporting
**Rationale:** Borderline band, included as the closest boots-on-the-ground evidence for a governance/tracking layer gap above skills; single commenter.

**Redundancy check:** Unique detail on tracking and governance gaps; no other card names them.

**Perspective category:** Boots-on-the-ground
