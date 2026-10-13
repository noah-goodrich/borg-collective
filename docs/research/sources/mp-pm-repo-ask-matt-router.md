# Source: mattpocock/skills: ask-matt SKILL.md (the intended end-to-end flow)

**Full citation:** Matt Pocock. "ask-matt" (SKILL.md), repository mattpocock/skills, main branch, accessed 2026-10-13.
**URL:** https://raw.githubusercontent.com/mattpocock/skills/main/skills/engineering/ask-matt/SKILL.md
**Date accessed:** 2026-10-13
**Evidence level:** 7 (primary design artifact; no outcome data)
**Research topic area:** PM / planning: how Matt Pocock structures work for agents (PRD/spec, grilling, tracer-bullet tickets, HITL/AFK labels, triage, TDD loop) and how it relates to established methods and to borg

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|---------------|
| 1 | Authority | 8/10 | The author's own map of how his skills are meant to chain. |
| 2 | Evidence Quality | 3/10 | Describes an intended flow; no measurements. |
| 3 | Currency | 10/10 | Updated through Oct 2026; names retro and implement-spec which only graduated in v1.3.0. |
| 4 | Intent | 7/10 | Router written to help users pick a skill, not to sell. |
| 5 | Bias & Objectivity | 6/10 | One expert's workflow presented as the main flow. |
| 6 | Logic & Coherence | 8/10 | Clear branch logic (multi-session or not; on-ramps for bugs, triage, wayfinder). |
| 7 | Corroboration | 7/10 | Matches the talk's grill, PRD, issues, AFK loop, QA sequence. |
| 8 | Intellectual Honesty | 7/10 | States where the flow does not apply (small work stays in one window; do not triage your own tickets). |
| 9 | Specificity | 9/10 | Names each step, hand-off condition and context-hygiene rule. |
| 10 | Relevance | 10/10 | Gives the whole planning-to-ship-to-retro chain in one place for comparison with /borg-plan to /borg-assimilate. |

**Score band:** borderline (weighted average about 6.95). Included with a named reason, see Inclusion Decision.

## Bias Guard Check

- [ ] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [x] Neutral / no strong reaction

## Key Findings

- Main flow: grill-with-docs, optional prototype detour, then (if multi-session) to-spec, to-tickets, then implement per ticket or implement-spec for the whole graph, closing with code-review and retro.
- Triage is an on-ramp for issues the maintainer did not create; tickets from to-tickets are already agent-ready and must not be triaged.
- Context hygiene is a PM rule: steps 1-3 stay in one unbroken window; each implement starts fresh from the ticket; retro runs in the session it reviews.
- retro is the learning step: it suggests changes to the agent's environment (checks, standards, navigation pointers), not the code. It is the closest Matt analogue to a debrief.

## Verified Quote(s)

**Location reference:** Section 'On-ramps', first bullet ('Bugs and requests piling up'), second paragraph; and section 'Context hygiene', first sentence.

> Triage is only for issues **you didn't create**: bug reports, incoming feature requests, anything that arrives raw. Tickets that `/to-tickets` produced are already agent-ready, so **don't triage them**.

> Keep steps 1–3 in **one unbroken context window**

**Access status:** live

## Inclusion Decision

**Decision:** Core
**Rationale:** Single best primary statement of the whole PM flow and where each step ends. Core despite a borderline band: it is the primary artifact for what Matt's method is, and the Evidence Quality dimension scores design documents low by construction.

**Redundancy check:** Overlaps to-tickets and wayfinder on detail, but is the only place the order and branch conditions are stated.

**Perspective category:** Practitioner
