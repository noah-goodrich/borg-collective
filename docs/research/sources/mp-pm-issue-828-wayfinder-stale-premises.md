# Source: mattpocock/skills issue 828: wayfinder resolutions don't propagate to the tickets they invalidate

**Full citation:** wrong7. "wayfinder: resolutions don't propagate to the tickets they invalidate, and parallel sessions inherit stale premises." GitHub issue #828, mattpocock/skills, opened 2026-08-10 (open). https://github.com/mattpocock/skills/issues/828. Accessed 2026-10-13.
**URL:** https://github.com/mattpocock/skills/issues/828
**Date accessed:** 2026-10-13
**Evidence level:** 5 (practitioner case report, n=1 team)
**Research topic area:** PM / planning: how Matt Pocock structures work for agents (PRD/spec, grilling, tracer-bullet tickets, HITL/AFK labels, triage, TDD loop) and how it relates to established methods and to borg

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|---------------|
| 1 | Authority | 3/10 | Unknown user; first-hand report from a small team. |
| 2 | Evidence Quality | 4/10 | One map of about eight tickets; no repeat measurements. |
| 3 | Currency | 10/10 | Aug 2026; open. |
| 4 | Intent | 8/10 | Constructive report with a proposed fix. |
| 5 | Bias & Objectivity | 7/10 | Admits the skill technically covers the case and explains why it failed anyway. |
| 6 | Logic & Coherence | 8/10 | Argument (ticket body is the only guaranteed context) is sound. |
| 7 | Corroboration | 5/10 | Echoed by #476 and #1174 but not an independent replication. |
| 8 | Intellectual Honesty | 8/10 | Self-critical about the team's own half-hearted update. |
| 9 | Specificity | 8/10 | Describes a specific decision (no event log) and the four stale tickets. |
| 10 | Relevance | 9/10 | Shows how decision-ticket maps rot, a concern for any multi-session plan. |

**Score band:** borderline (weighted average about 5.95). Included with a named reason, see Inclusion Decision.

## Bias Guard Check

- [ ] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [x] Neutral / no strong reaction

## Key Findings

- About eight tickets in, one decision removed a whole concept, but four open tickets still described the old design; a fresh session would have resolved them against dead premises.
- The skill's only guard is a trailing sentence about updating invalidated tickets, which the team skipped half-heartedly.
- The failure was caught only because the same developer noticed, not by any check.

## Verified Quote(s)

**Location reference:** Issue body, paragraph beginning 'But in practice that sentence didn't save us'.

> the ticket body is the only context a fresh session is guaranteed to load.

**Access status:** live

## Inclusion Decision

**Decision:** Supporting
**Rationale:** Borderline on authority; included as boots-on-the-ground evidence that written plans go stale and that Matt's own doc-rot warning describes a real failure.

**Redundancy check:** Distinct from #476; ties to Matt's doc-rot warning in the talk.

**Perspective category:** Boots-on-the-ground
