# Source: AI Engineer Europe 2026: Full Walkthrough, Workflow for AI Coding (Matt Pocock), write-up page

**Full citation:** Matt Pocock. "Full Walkthrough: Workflow for AI Coding." AI Engineer Europe 2026 (1:36:30 talk), page with generated sectioned write-up and transcript. https://ai.engineer/talks/ai-coding-workflow. Accessed 2026-10-13.
**URL:** https://ai.engineer/talks/ai-coding-workflow
**Date accessed:** 2026-10-13
**Evidence level:** 7 (expert talk; the summary text is a generated write-up of it, not Matt's wording)
**Research topic area:** PM / planning: how Matt Pocock structures work for agents (PRD/spec, grilling, tracer-bullet tickets, HITL/AFK labels, triage, TDD loop) and how it relates to established methods and to borg

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|---------------|
| 1 | Authority | 6/10 | The talk is Matt's; the sectioned prose on the page is a derived write-up, so authority is split. |
| 2 | Evidence Quality | 4/10 | Live demo on a toy product (gamification) with no metrics. |
| 3 | Currency | 10/10 | April 2026 conference talk. |
| 4 | Intent | 7/10 | Conference programme content. |
| 5 | Bias & Objectivity | 6/10 | Summary is consistent with the talk, though generated and unreviewed. |
| 6 | Logic & Coherence | 7/10 | Walks one idea through grill, PRD, issues, AFK loop, review, QA. |
| 7 | Corroboration | 7/10 | Matches the repo skills and the Pragmatic Engineer interview. |
| 8 | Intellectual Honesty | 8/10 | Records the limits Matt concedes: agents write more than humans can review; passing tests missed a missing table. |
| 9 | Specificity | 8/10 | Timestamped sections; names HITL alignment, AFK issues, night shift, doc rot. |
| 10 | Relevance | 10/10 | Only source tying PRD, kanban issues, AFK labels, QA feedback and doc rot together in one demo. |

**Score band:** borderline (weighted average about 6.60). Included with a named reason, see Inclusion Decision.

## Bias Guard Check

- [ ] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [x] Neutral / no strong reaction

## Key Findings

- Alignment is explicitly human-in-the-loop: Grill Me interviews the human (dozens of questions) before a PRD captures the destination; this stage is not for an unattended loop.
- The PRD is turned into a kanban board of issues with explicit blockers and AFK eligibility; reviewing them for vertical slices is the crucial human check.
- Implementation runs as a 'night shift' of AFK issues, with test-first development and fresh-context review; QA findings feed new issues back into the backlog.
- He warns about doc rot: completed PRDs left in the repo mislead future agents, so close or remove stale planning artifacts.
- He concedes he has no complete answer to agents producing more code than humans can review in small PRs.

## Verified Quote(s)

**Location reference:** Section 05 'Shape the architecture agents inherit and scale only what remains coherent' (third paragraph, 'workflow remains cyclical'), section 04 'Automate implementation, not ownership of quality' (fourth paragraph), and section 03 first paragraph.

> completed PRDs left in a repository can mislead future agents after requirements and code change, so he prefers closing or removing stale planning artifacts rather than treating them as permanent authority.

> Automation does not remove the need for human QA and code review.

> of independently actionable issues with explicit blocking relationships.

**Access status:** live

## Inclusion Decision

**Decision:** Core
**Rationale:** Best single account of how Matt connects planning artifacts to AFK execution and QA; the generated-summary caveat is recorded in Authority. Core despite a borderline band: it is the primary artifact for what Matt's method is, and the Evidence Quality dimension scores design documents low by construction.

**Redundancy check:** Adds doc rot, night shift and the human-QA caveat absent from the repo files.

**Perspective category:** Practitioner
