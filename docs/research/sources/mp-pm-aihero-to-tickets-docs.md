# Source: AI Hero: /to-tickets docs page (tracer bullets, failure modes, manual dispatch)

**Full citation:** Matt Pocock (AI Hero). "/to-tickets" skill documentation page. https://www.aihero.dev/skills-to-tickets. Page dated Aug 24, 2026; accessed 2026-10-13.
**URL:** https://www.aihero.dev/skills-to-tickets
**Date accessed:** 2026-10-13
**Evidence level:** 7 (expert documentation with an unverified field report)
**Research topic area:** PM / planning: how Matt Pocock structures work for agents (PRD/spec, grilling, tracer-bullet tickets, HITL/AFK labels, triage, TDD loop) and how it relates to established methods and to borg

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|---------------|
| 1 | Authority | 7/10 | Matt's own documentation site for the skill. |
| 2 | Evidence Quality | 4/10 | Includes a field anecdote (a 26-ticket horizontal stack) with no named team or data. |
| 3 | Currency | 10/10 | Dated Aug 2026. |
| 4 | Intent | 6/10 | AI Hero sells training, so the page is also marketing for the skill ecosystem. |
| 5 | Bias & Objectivity | 5/10 | Promotional site, but the 'common problems' list is unusually frank. |
| 6 | Logic & Coherence | 7/10 | Explains why horizontal slicing fails and gives a per-ticket demo test. |
| 7 | Corroboration | 6/10 | Failure modes match open issues #310 and #508 in the repo. |
| 8 | Intellectual Honesty | 8/10 | Admits the skill 'still produces' layer-sliced tickets sometimes and that implement does not reliably close tickets. |
| 9 | Specificity | 9/10 | Specific symptoms, causes and checks (acceptance criteria that cannot fail at the base commit). |
| 10 | Relevance | 10/10 | Directly about tracer-bullet ticketing, the core of the question. |

**Score band:** borderline (weighted average about 6.65). Included with a named reason, see Inclusion Decision.

## Bias Guard Check

- [ ] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [x] Neutral / no strong reaction

## Key Findings

- A horizontal slice ships one layer so nothing works until all land; a vertical slice (tracer bullet) is verifiable alone and 'owns everything it grades'.
- Reported case: a 26-ticket stack sliced by layer cost roughly twenty agent runs per closed ticket, about three quarters rework; the team's post-mortem blamed the slicing, not the implementations (anecdote, unnamed).
- The review gate is a single question per ticket, 'what can I demo when this is done?'; nothing is published until the user approves the breakdown.
- Dispatch is manual: no auto-dispatch mode; count unblocked tickets, open that many fresh sessions, and update ticket state yourself because implement does not reliably close it.
- Acceptance criteria can pass before any work is done; check each can fail at the commit the implementer starts from.

## Verified Quote(s)

**Location reference:** Heading 'Tracer bullets, not layers', second paragraph; heading 'The tickets are published. How do I actually run them?', first sentence; and the paragraph beginning 'Two things happen before anything is published'.

> One team ran a 26-ticket stack sliced by layer (corpus, producer, aggregator, selector) and got roughly twenty agent runs per closed ticket, about three quarters of them rework.

> The skill stops at the artifact, and there is no auto-dispatch mode.

> Nothing reaches the tracker until you approve, and that quiz is the place to push back.

**Access status:** live

## Inclusion Decision

**Decision:** Core
**Rationale:** Matt's own explanation plus frank failure modes; the best single source on how the ticket step behaves in practice. Core despite a borderline band: it is the primary artifact for what Matt's method is, and the Evidence Quality dimension scores design documents low by construction.

**Redundancy check:** Adds the failure-mode list and manual-dispatch caveat absent from SKILL.md.

**Perspective category:** Practitioner
