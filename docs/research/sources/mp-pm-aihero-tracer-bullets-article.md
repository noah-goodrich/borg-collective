# Source: AI Hero: Tracer Bullets, Keeping AI Slop Under Control (Matt Pocock)

**Full citation:** Matt Pocock. "Tracer Bullets: Keeping AI Slop Under Control." AI Hero. https://www.aihero.dev/tracer-bullets. Updated Jan 22, 2026; accessed 2026-10-13.
**URL:** https://www.aihero.dev/tracer-bullets
**Date accessed:** 2026-10-13
**Evidence level:** 7 (expert opinion with one worked example)
**Research topic area:** PM / planning: how Matt Pocock structures work for agents (PRD/spec, grilling, tracer-bullet tickets, HITL/AFK labels, triage, TDD loop) and how it relates to established methods and to borg

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|---------------|
| 1 | Authority | 7/10 | Matt's own article on his method. |
| 2 | Evidence Quality | 3/10 | One personal example; no measured comparison. |
| 3 | Currency | 10/10 | Updated Jan 2026. |
| 4 | Intent | 6/10 | Educational content on a site that sells training. |
| 5 | Bias & Objectivity | 5/10 | First-person advocacy, no counter-case. |
| 6 | Logic & Coherence | 7/10 | Clear causal story: agent builds layers in the dark, then integration fails. |
| 7 | Corroboration | 8/10 | Idea traces to The Pragmatic Programmer (Artima interview) and recurs in his talk and Orosz interview. |
| 8 | Intellectual Honesty | 6/10 | Presents 'my results' as a single issue, so overclaim risk is low but evidence is thin. |
| 9 | Specificity | 6/10 | Gives a ready prompt and a worked issue breakdown, but little quantification. |
| 10 | Relevance | 9/10 | Source of the vertical-slice rationale used throughout the skills. |

**Score band:** borderline (weighted average about 6.25). Included with a named reason, see Inclusion Decision.

## Bias Guard Check

- [x] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [ ] Neutral / no strong reaction

## Key Findings

- The rationale: agents tend to build whole layers in isolation and only test at the end ('outrunning your headlights'), so slop and review burden pile up.
- The fix is a loop: build one small slice end to end, test it, get feedback, move to the next slice in a fresh context window.
- The classic concept is credited to The Pragmatic Programmer; Matt argues the discipline applies harder to AI because context limits make it non-negotiable.
- The article now links /prototype as what 'automates' the throwaway-code half of the book's distinction.

## Verified Quote(s)

**Location reference:** Heading 'The Solution: Tracer Bullets', first paragraph; heading 'The Problem: Too Much Slop', fourth paragraph.

> It's a small, end-to-end slice of functionality that touches all the layers of your system at once.

> It doesn't stop to validate assumptions or get feedback.

**Access status:** live

## Inclusion Decision

**Decision:** Supporting
**Rationale:** Primary statement of the idea in Matt's words; no outcome data, so supporting rather than core.

**Redundancy check:** Overlaps the to-tickets docs page but carries the origin story and the Pragmatic Programmer attribution.

**Perspective category:** Practitioner
