# Source: mattpocock/skills: to-tickets SKILL.md (current main)

**Full citation:** Matt Pocock. "to-tickets" (SKILL.md), repository mattpocock/skills, main branch, accessed 2026-10-13. Repo last pushed 2026-10-13.
**URL:** https://raw.githubusercontent.com/mattpocock/skills/main/skills/engineering/to-tickets/SKILL.md
**Date accessed:** 2026-10-13
**Evidence level:** 7 (primary design artifact by the practitioner who created it; no outcome data)
**Research topic area:** PM / planning: how Matt Pocock structures work for agents (PRD/spec, grilling, tracer-bullet tickets, HITL/AFK labels, triage, TDD loop) and how it relates to established methods and to borg

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|---------------|
| 1 | Authority | 8/10 | Primary source: the skill text itself, by the author, on the live default branch. |
| 2 | Evidence Quality | 3/10 | A prompt/spec, not an evaluation; it asserts rules and cites no outcome data. |
| 3 | Currency | 10/10 | Edited within days of access (repo pushed 2026-10-13); this is the current wording. |
| 4 | Intent | 7/10 | Free MIT-licensed skill; the author also sells training, but the file itself is a working tool. |
| 5 | Bias & Objectivity | 6/10 | Self-description by the author; no neutral party reviewed it. |
| 6 | Logic & Coherence | 8/10 | Rules are internally consistent (vertical slice, blocking edges, quiz gate, wide-refactor exception). |
| 7 | Corroboration | 7/10 | Matches the docs page and talk (aihero.dev to-tickets page, AI Engineer talk) on every rule checked. |
| 8 | Intellectual Honesty | 7/10 | Names its own exception (wide refactors need expand-contract) instead of claiming slicing always works. |
| 9 | Specificity | 9/10 | Exact template for issue bodies, labels, blocking-edge handling, and local-file layout. |
| 10 | Relevance | 10/10 | This is the ticket-structuring step the PM comparison is about. |

**Score band:** borderline (weighted average about 6.95). Included with a named reason, see Inclusion Decision.

## Bias Guard Check

- [ ] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [x] Neutral / no strong reaction

## Key Findings

- Tickets are tracer-bullet vertical slices: each cuts a narrow complete path through every layer, is demoable on its own, and is sized for one fresh context window.
- Each ticket declares blocking edges (native tracker links on GitHub/Linear, text in one file per ticket locally); any ticket whose blockers are done is on the 'frontier'.
- Published tickets get the ready-for-agent label by default because they are 'agent-grabbable by construction'; the user must approve the breakdown first (a quiz step on granularity and edges).
- Wide mechanical refactors are carved out of vertical slicing and sequenced as expand-migrate-contract.
- There is no value ranking, time budget, or stop rule in the skill: ordering comes only from the blocking graph.

## Verified Quote(s)

**Location reference:** Section 'Process', step 3 'Draft vertical slices' (vertical-slice-rules block, bullets 1 and 3, then the paragraph on blocking edges) and step 5 'Publish the tickets' (last sentence of the real-tracker bullet).

> Each slice cuts a narrow but COMPLETE path through every layer (schema, API, UI, tests): vertical, NOT a horizontal slice of one layer

> Each slice is sized to fit in a single fresh context window

> A ticket with no blockers can start immediately.

> the tickets are agent-grabbable by construction

**Access status:** live

## Inclusion Decision

**Decision:** Core
**Rationale:** Primary text for the ticket-structuring half of Matt's method; every comparison to borg's directives and stacks rests on it. Core despite a borderline band: it is the primary artifact for what Matt's method is, and the Evidence Quality dimension scores design documents low by construction.

**Redundancy check:** Not redundant: the docs page and talk describe it, but only this file is the executable definition.

**Perspective category:** Practitioner
