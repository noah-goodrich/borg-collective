# Source: mattpocock/skills: triage SKILL.md (state machine, ready-for-agent / ready-for-human)

**Full citation:** Matt Pocock. "triage" (SKILL.md), repository mattpocock/skills, main branch, accessed 2026-10-13.
**URL:** https://raw.githubusercontent.com/mattpocock/skills/main/skills/engineering/triage/SKILL.md
**Date accessed:** 2026-10-13
**Evidence level:** 7 (primary design artifact; no outcome data)
**Research topic area:** PM / planning: how Matt Pocock structures work for agents (PRD/spec, grilling, tracer-bullet tickets, HITL/AFK labels, triage, TDD loop) and how it relates to established methods and to borg

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|---------------|
| 1 | Authority | 8/10 | Author's own skill on the live default branch. |
| 2 | Evidence Quality | 3/10 | Defines a procedure; no measurements of how well triage works. |
| 3 | Currency | 10/10 | Current main as of access date; PR triage was added in 2026. |
| 4 | Intent | 7/10 | Working tool for the author's own open-source repo, where he is the maintainer. |
| 5 | Bias & Objectivity | 6/10 | Self-described; designed around one maintainer's needs. |
| 6 | Logic & Coherence | 8/10 | Coherent: two category roles, five state roles, exactly-one-each rule, stated transitions. |
| 7 | Corroboration | 6/10 | Consistent with the setup skill and docs page; no independent adopter report read. |
| 8 | Intellectual Honesty | 7/10 | Includes a quick override ('trust the maintainer') and flags unusual transitions rather than hiding them. |
| 9 | Specificity | 9/10 | Names every role, transition, and the comment disclaimer required on AI-posted triage notes. |
| 10 | Relevance | 8/10 | Defines the HITL/AFK split in label form, which borg has no tracker equivalent for. |

**Score band:** borderline (weighted average about 6.80). Included with a named reason, see Inclusion Decision.

## Bias Guard Check

- [ ] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [x] Neutral / no strong reaction

## Key Findings

- Triage is a five-state machine (needs-triage, needs-info, ready-for-agent, ready-for-human, wontfix) plus a bug/enhancement category; every issue carries exactly one of each.
- ready-for-agent means 'fully specified, ready for an AFK agent'; ready-for-human means it needs human implementation. This is the AFK/HITL labelling on the GitHub issue itself.
- Triage verifies the claim first (reproduce the bug, check the PR diff) and checks redundancy and prior rejection against .out-of-scope notes before grilling.
- Rejected enhancements are written to an out-of-scope knowledge base so repeats are caught; already-implemented requests are closed without polluting it.

## Verified Quote(s)

**Location reference:** Section 'Roles' (state roles list, bullets 3 and 4) and the first sentence after the role lists.

> `ready-for-agent`: fully specified, ready for an AFK agent

> `ready-for-human`: needs human implementation

> Every triaged issue should carry exactly one category role and one state role.

**Access status:** live

## Inclusion Decision

**Decision:** Core
**Rationale:** Primary source for the human-in-the-loop versus autonomous labels and for how planning state lives in issue labels. Core despite a borderline band: it is the primary artifact for what Matt's method is, and the Evidence Quality dimension scores design documents low by construction.

**Redundancy check:** Complements to-tickets: that skill applies ready-for-agent; this one defines and assigns it.

**Perspective category:** Practitioner
