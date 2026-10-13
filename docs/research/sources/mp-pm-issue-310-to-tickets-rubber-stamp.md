# Source: mattpocock/skills issue 310: to-tickets vertical-slice rule has no completeness check

**Full citation:** iKon85. "to-tickets: vertical-slice rule has no completeness check, so layer-cut slices can leave a connecting path unowned." GitHub issue #310, mattpocock/skills, opened 2026-06-07 (open, 3 comments). https://github.com/mattpocock/skills/issues/310. Accessed 2026-10-13.
**URL:** https://github.com/mattpocock/skills/issues/310
**Date accessed:** 2026-10-13
**Evidence level:** 8 (user report with generic failure mode)
**Research topic area:** PM / planning: how Matt Pocock structures work for agents (PRD/spec, grilling, tracer-bullet tickets, HITL/AFK labels, triage, TDD loop) and how it relates to established methods and to borg

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|---------------|
| 1 | Authority | 3/10 | Unknown user reporting on a public tracker. |
| 2 | Evidence Quality | 3/10 | Describes a failure mode in prose; no counted instances in the opening text. |
| 3 | Currency | 10/10 | June 2026; open. |
| 4 | Intent | 8/10 | Constructive bug report with a suggested verification step. |
| 5 | Bias & Objectivity | 7/10 | Analyses the skill text without overclaiming. |
| 6 | Logic & Coherence | 8/10 | Explains why 'quiz the user' misses the gap. |
| 7 | Corroboration | 6/10 | The AI Hero page admits the skill 'still produces' layer-sliced tickets; not independent. |
| 8 | Intellectual Honesty | 6/10 | Presents the failure as a generic mode, not a measured rate. |
| 9 | Specificity | 8/10 | Concrete example (captured versus surfaced data, connecting step owned by neither slice). |
| 10 | Relevance | 9/10 | Directly about whether vertical slicing is actually checked. |

**Score band:** borderline (weighted average about 5.70). Included with a named reason, see Inclusion Decision.

## Bias Guard Check

- [ ] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [x] Neutral / no strong reaction

## Key Findings

- Layer-named slices can each look reasonable while the union omits the connecting step, owned by no ticket.
- When to-tickets runs on a pre-authored plan, the quiz step tends to rubber-stamp the existing cut rather than re-derive it.
- The proposed fix is outcome-titled slices ('user action to visible result') and a completeness check before publishing.

## Verified Quote(s)

**Location reference:** Issue body, section 'Summary', first paragraph, last sentence.

> Step 4 ("Quiz the user") tends to rubber-stamp the existing cut rather than re-derive it.

**Access status:** live

## Inclusion Decision

**Decision:** Supporting
**Rationale:** Borderline on authority; kept as boots-on-the-ground evidence that the vertical-slice rule lacks a completeness check, which Matt's docs page partly concedes.

**Redundancy check:** Distinct from #508: slicing quality versus ticket closure.

**Perspective category:** Boots-on-the-ground
