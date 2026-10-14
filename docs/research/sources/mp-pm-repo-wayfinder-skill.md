# Source: mattpocock/skills: wayfinder SKILL.md (decision-ticket map for work bigger than one session)

**Full citation:** Matt Pocock. "wayfinder" (SKILL.md), repository mattpocock/skills, main branch, accessed 2026-10-13.
**URL:** https://raw.githubusercontent.com/mattpocock/skills/main/skills/engineering/wayfinder/SKILL.md
**Date accessed:** 2026-10-13
**Evidence level:** 7 (primary design artifact; no outcome data)
**Research topic area:** PM / planning: how Matt Pocock structures work for agents (PRD/spec, grilling, tracer-bullet tickets, HITL/AFK labels, triage, TDD loop) and how it relates to established methods and to borg

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|---------------|
| 1 | Authority | 8/10 | Author's own skill on the live default branch. |
| 2 | Evidence Quality | 3/10 | Design text only; open issues show field problems but the skill itself cites no results. |
| 3 | Currency | 10/10 | Revised repeatedly in Aug-Oct 2026 (open issues and changelog). |
| 4 | Intent | 7/10 | Free tool; positioned as the 'most cognitively demanding' flow in the router, with candid cost framing. |
| 5 | Bias & Objectivity | 6/10 | Author's own design, still being changed as users report faults. |
| 6 | Logic & Coherence | 7/10 | Map, fog of war, out-of-scope and frontier concepts hang together, but open issues report gaps (stale tickets, concurrency). |
| 7 | Corroboration | 6/10 | Same concepts appear in the router and changelog; practitioner issues (#476, #828) confirm real use. |
| 8 | Intellectual Honesty | 8/10 | Says plainly it plans rather than builds, and that no map is needed if the way is already clear. |
| 9 | Specificity | 9/10 | Gives the exact map body template, ticket types, claim protocol and a one-ticket-per-session rule. |
| 10 | Relevance | 9/10 | Closest thing in Matt's set to a multi-session project plan with decisions-so-far; comparable to borg-plan and stacks. |

**Score band:** borderline (weighted average about 6.85). Included with a named reason, see Inclusion Decision.

## Bias Guard Check

- [ ] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [x] Neutral / no strong reaction

## Key Findings

- A wayfinder map is one tracker issue (label wayfinder:map) that is an index: Destination, Notes, Decisions so far, Not yet specified, Out of scope. Detail lives in child decision tickets.
- Every ticket is HITL (worked with a live human) or AFK (agent alone). Types are research, prototype, grilling, task; only 'task' does rather than decides.
- A session claims a ticket by assigning it before any work; the frontier is open, unblocked, unclaimed children; at most one ticket per session except research.
- It plans by default: 'produce decisions, not deliverables'. The router says the map hands off at /to-spec rather than looping to /implement.
- Fog of war is an explicit section: in-scope but not-yet-sharp questions graduate to tickets as the frontier advances; out-of-scope work is closed and never graduates.

## Verified Quote(s)

**Location reference:** Section 'The Map' (second paragraph), section 'Tickets' (final paragraph before 'The answer isn't part of the body'), and section 'Ticket Types' (opening paragraph).

> Every ticket is either **HITL** (human in the loop, worked _with_ a human who speaks for themselves) or **AFK**, driven by the agent alone.

> The map is an **index**, not a store.

> A session **claims** a ticket by assigning it to the dev driving the map, **first**, before any work, so concurrent sessions skip it.

**Access status:** live

## Inclusion Decision

**Decision:** Core
**Rationale:** Primary source for how planning state and decisions live in GitHub issues for work larger than one session; the structural analogue of a borg stack. Core despite a borderline band: it is the primary artifact for what Matt's method is, and the Evidence Quality dimension scores design documents low by construction.

**Redundancy check:** Distinct from to-tickets: decisions (planning) versus slices (building).

**Perspective category:** Practitioner
