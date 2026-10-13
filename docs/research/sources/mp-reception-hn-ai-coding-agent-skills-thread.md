# Source: Hacker News thread "AI Coding Agent Skills for Real Engineers" (14 comments)

**Full citation:** Hacker News commenters (hungryhobbit, fishfasell, clickety_clack, mock-possum, ceuk, dalmo3, tonytamps and others). "AI Coding Agent Skills for Real Engineers" (submission of github.com/mattpocock/skills). news.ycombinator.com. 2026-09-01. 43 points.
**URL:** https://news.ycombinator.com/item?id=49529329
**Date accessed:** 2026-10-13
**Evidence level:** 8 (Anecdotal / personal experience; crowd of independent voices)
**Research topic area:** Reception of Matt Pocock skills (mp-reception)

## Credibility Scores

| # | Dimension | Score | Note |
|---|-----------|-------|------|
| 1 | Authority | 3/10 | anon HN handles |
| 2 | Evidence Quality | 3/10 | opinion, some detail |
| 3 | Currency | 10/10 | six weeks old |
| 4 | Intent | 7/10 | organic discussion |
| 5 | Bias & Objectivity | 5/10 | mixed, lopsided skeptic |
| 6 | Logic & Coherence | 5/10 | arguments hold |
| 7 | Corroboration | 7/10 | matches issue, kaizen |
| 8 | Intellectual Honesty | 5/10 | some hedging |
| 9 | Specificity | 5/10 | quotable claims |
| 10 | Relevance | 9/10 | direct reception |

Justifications (one line per dimension, same order):

1. Authority: Anonymous HN accounts with no verifiable credentials, though several describe real practice.
2. Evidence Quality: Mostly opinion and personal workflow experience; no measurements.
3. Currency: Posted 2026-09-01 and read 2026-10-13, so current for this fast-moving space.
4. Intent: Organic discussion with no sales motive; one commenter plugs their own product.
5. Bias & Objectivity: Skews skeptical (nickels, one-AGENTS.md argument) but includes defenders (dalmo3, tonytamps).
6. Logic & Coherence: The "put TDD in AGENTS.md" and "imported instructions" arguments are coherent though untested.
7. Corroboration: The same objections appear in GitHub issue 1071 and the Kaizen Craft guide, and SkillsBench supports the focused-skill point.
8. Intellectual Honesty: Several commenters hedge ("To each his own", "Matt Pocock is still a nice guy").
9. Specificity: Names specific mechanisms (jargon-before/after example, SKILL.md vs AGENTS.md) but gives no data.
10. Relevance: It is the only HN submission of the repo with real discussion, so directly on topic.

**Score band:** borderline

## Bias Guard Check

- [ ] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [x] Neutral / no strong reaction

## Key Findings

- Top-level reaction was skeptical: skills of this kind are "extremely specific to that dev and their workflow" and rarely transfer (hungryhobbit, fishfasell).
- Plain-instruction argument: TDD can be one line in AGENTS.md/CLAUDE.md, and a longer definition may be worse than the model's trained one (clickety_clack).
- Imported instructions are a hidden-behavior risk: a commenter dislikes the model acting on rules they never wrote (mock-possum).
- Defenders say exposure to a strong engineer's skills is still educational (dalmo3, tonytamps), and a commenter questioned the CONTEXT.md jargon example as harder to read (ceuk).
- One commenter says the prose is noisy and should be run through an LLM for cruft (Supermancho), echoing the "weirdly worded" complaints elsewhere.

## Verified Quote(s)

**Location reference:** Top-level comments by clickety_clack, mock-possum, and the reply by fishfasell under hungryhobbit, on HN item 49529329 (text verified against the HN Algolia mirror of the same item).

> If you’re detailing something like TDD, you’re probably hampering the model by giving it a definition that is less accurate than the one it has learned in training.

> It’s also unsettling catching it behaving in an odd way, and realizing that it was taking a cue from instructions you never wrote, but imported from elsewhere.

> Skills are hardly transferrable unless you are just focusing on globally applicable things like syntax, structure, etc.

**Access status:** live

## Inclusion Decision

**Decision:** Supporting
**Rationale:** Borderline band, included as the best available direct evidence of practitioner skepticism; gap-fill for the Boots-on-the-ground/Contrarian categories, never used alone for a claim.

**Redundancy check:** Corroborated independently by the GitHub issue and Kaizen Craft guide; adds the "AGENTS.md is enough" and imported-instruction objections that neither covers.

**Perspective category:** Contrarian
