# Source: Your AI Coding Workflow is Killing Your Productivity. You Just Moved the Bottleneck.

**Full citation:** Folkman, T. Substack. 2026-02-22.
**URL:** https://tylerfolkman.substack.com/p/i-built-a-one-person-software-factory
**Date accessed:** 2026-10-03
**Evidence level:** 8 (Anecdotal / personal experience)
**Research topic area:** Solo developer, AI-agent delivery (T3 flow)

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|---------------|
| 1 | Authority | 3/10 | Individual practitioner/blogger; credentials not independently verified. |
| 2 | Evidence Quality | 2/10 | First-person account of one workflow; some cited statistics (84% use AI) not sourced on the page text read. |
| 3 | Currency | 9/10 | Feb 2026. |
| 4 | Intent | 4/10 | Newsletter growth and personal brand. |
| 5 | Bias & Objectivity | 4/10 | Promotes his own system; includes failure modes of alternatives he tried. |
| 6 | Logic & Coherence | 5/10 | Story is coherent but survivorship-biased. |
| 7 | Corroboration | 4/10 | Review-bottleneck theme is echoed by Faros and Osmani, not this author's numbers. |
| 8 | Intellectual Honesty | 5/10 | Admits failed approaches (manual review, YOLO) and that agents game tests. |
| 9 | Specificity | 6/10 | Concrete anecdotes (50+ diffs/day, 453 commits, 17 skills). |
| 10 | Relevance | 8/10 | Rare first-person solo, parallel-agent flow experience. |

**Score band:** reject
(Intermediate weighted average ~4.2; the band is the disposition.)

## Bias Guard Check

- [ ] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [x] Neutral / no strong reaction

## Key Findings

- Running several Claude Code panes in parallel made the human the bottleneck: the AI wrote code faster than the author could verify it.
- Reading 50+ diffs per day yielded real catches only about 5% of the time (self-reported), so blanket manual review was low-yield.
- Letting agents ship and checking tests afterwards failed because agents 'game tests' (an assertion like result !== undefined passed incorrect code).
- The author's fix is a staged, self-verifying workflow; its efficacy is only self-reported.

## Verified Quote(s)

**Location reference:** https://tylerfolkman.substack.com/p/i-built-a-one-person-software-factory. Quote 1: opening
section before the first heading ("The Trust Problem"), paragraphs 3 and 4 after the byline ("The AI was writing code
faster than I could verify it." and "I was the bottleneck." are consecutive one-sentence paragraphs; the quote joins
them). Quote 2: section "The Trust Problem" (paragraphs counted after the heading), paragraph 8 (beginning "Pure
YOLO."), fourth sentence.

Card revised: 2026-10-03 (location audit before re-verification)

> The AI was writing code faster than I could verify it. I was the bottleneck.

> Agents game tests.

**Access status:** live

## Inclusion Decision

**Decision:** Excluded
**Rationale:** (Band reject: cut per rubric; card kept as an audit trail and for the gap it documents.) Anecdote-level, unverified credentials, self-reported efficacy: cut as the weakest source in the T3 set. It is the only first-person solo parallel-agent account found, so it is logged as evidence of a Boots-on-the-ground gap rather than used as a claim source.

**Redundancy check:** Echoes Faros and Osmani; adds solo-operator first-person detail.

**Perspective category:** Boots-on-the-ground
