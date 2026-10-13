# Source: mattpocock/skills issue 508: /implement has no completion step, finished tickets are never marked done

**Full citation:** HorvathAlteisen. "/implement has no completion step, finished tickets are never marked done." GitHub issue #508, mattpocock/skills, opened 2026-07-10 (open, 13 comments at access). https://github.com/mattpocock/skills/issues/508. Accessed 2026-10-13.
**URL:** https://github.com/mattpocock/skills/issues/508
**Date accessed:** 2026-10-13
**Evidence level:** 8 (user report, corroborated by the maintainer docs page)
**Research topic area:** PM / planning: how Matt Pocock structures work for agents (PRD/spec, grilling, tracer-bullet tickets, HITL/AFK labels, triage, TDD loop) and how it relates to established methods and to borg

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|---------------|
| 1 | Authority | 3/10 | Unknown user reporting on a public tracker. |
| 2 | Evidence Quality | 3/10 | Single reproducible observation with a quoted analysis of the skills' contracts. |
| 3 | Currency | 10/10 | July 2026; still open. |
| 4 | Intent | 8/10 | Good-faith bug report proposing a fix. |
| 5 | Bias & Objectivity | 7/10 | Reasoned from the skill texts, not from opinion. |
| 6 | Logic & Coherence | 7/10 | Argument is logically tight (frontier needs closed blockers). |
| 7 | Corroboration | 6/10 | The AI Hero to-tickets page independently says implement does not reliably close tickets. |
| 8 | Intellectual Honesty | 7/10 | Frames it as a gap, not a preference. |
| 9 | Specificity | 9/10 | Quotes the specific lines of three skills. |
| 10 | Relevance | 9/10 | Shows where planning state (ticket status) goes stale in the tracker. |

**Score band:** borderline (weighted average about 5.75). Included with a named reason, see Inclusion Decision.

## Bias Guard Check

- [ ] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [x] Neutral / no strong reaction

## Key Findings

- After /implement finishes, the issue is left open with no closing comment, so the 'frontier' of unblocked tickets goes stale.
- The failure comes from a handoff gap between skills: to-tickets and wayfinder rely on ticket state that implement never writes.
- Maintainer docs confirm the behaviour: update ticket state yourself (AI Hero to-tickets page).

## Verified Quote(s)

**Location reference:** Issue body, section 'Why this is a gap, not a preference', final paragraph.

> After the first ticket, the frontier on the tracker is stale: nothing is closed, so no dependent ticket ever becomes visibly unblocked

**Access status:** live

## Inclusion Decision

**Decision:** Supporting
**Rationale:** Borderline on authority; included as boots-on-the-ground evidence of a real planning-state gap, corroborated by Matt's own docs.

**Redundancy check:** Distinct from the other issue cards: this is the done-signal gap.

**Perspective category:** Boots-on-the-ground
