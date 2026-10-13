# Source: AI Hero post: Tracer Bullets, Keeping AI Slop Under Control

**Full citation:** Matt Pocock. "Tracer Bullets: Keeping AI Slop Under Control." aihero.dev/tracer-bullets. Updated 2026-01-22.
**URL:** https://www.aihero.dev/tracer-bullets
**Date accessed:** 2026-10-13
**Evidence level:** 7 (author's thought leadership)
**Research topic area:** WHAT IT IS (primary sources): mattpocock/skills, Sandcastle, AI Hero, Matt's stated philosophy

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|---------------|
| 1 | Authority | 8/10 | Matt's own explanation of the technique that underpins to-tickets and tdd. |
| 2 | Evidence Quality | 3/10 | Reasoned argument citing The Pragmatic Programmer; no measurements. |
| 3 | Currency | 8/10 | January 2026, pre-dates the skills repo but the concept is unchanged in v1.3. |
| 4 | Intent | 5/10 | Educational with a product halo. |
| 5 | Bias & Objectivity | 5/10 | Argues one position; does not examine when vertical slicing fails (the later to-tickets docs add the wide-refactor exception). |
| 6 | Logic & Coherence | 8/10 | Clear problem, solution, procedure. |
| 7 | Corroboration | 6/10 | Pragmatic Engineer reports the same origin ('tracer bullet' as a leading word); to-tickets docs repeat it. |
| 8 | Intellectual Honesty | 5/10 | Does not discuss failure modes of the method. |
| 9 | Specificity | 7/10 | Gives a concrete five-step loop and a worked failure example. |
| 10 | Relevance | 8/10 | Explains the central design concept behind the planning skills. |

**Score band:** borderline

(Intermediate weighted average about 6.1; the disposition is the band word.)

## Bias Guard Check

- [ ] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [x] Neutral / no strong reaction

## Key Findings

- Failure mode named: AI sycophancy makes the agent build whole layers in isolation ('outrunning your headlights') and only later find the integration is wrong.
- Fix: build one tiny end-to-end vertical slice, test immediately, get feedback, move to the next slice in a fresh context window.
- This is the design rationale for to-tickets (each ticket a tracer bullet sized for a single fresh context) and for tdd 'one vertical slice at a time'.
- Concept source is The Pragmatic Programmer, consistent with the README's citation habit.

## Verified Quote(s)

**Location reference:** Quote 1: Section 'The Problem: Too Much Slop', first sentence; Quote 2: Section 'The Problem: Too Much Slop', subsection 'What This Looks Like in Practice', last paragraph; Quote 3: Section 'The Solution: Tracer Bullets', paragraph after the book reference

> AI has a natural inclination to sycophancy.

> The pragmatic programmer calls this "outrunning your headlights."

> Instead of building horizontal layers in isolation, you build one tiny vertical slice:

**Access status:** live

## Inclusion Decision

**Decision:** Supporting
**Rationale:** Borderline band: included as the primary source for the design idea behind to-tickets (gap-fill), directly relevant to borg's stacks and acceptance criteria.

**Redundancy check:** Adds the reasoning behind the vertical-slice rule that the README only summarises.

**Perspective category:** Practitioner
