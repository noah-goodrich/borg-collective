# Source: martinfowler.com: Understanding Spec-Driven-Development, Kiro, spec-kit, and Tessl (Boeckeler)

**Full citation:** Birgitta Boeckeler. "Understanding Spec-Driven-Development: Kiro, spec-kit, and Tessl." martinfowler.com (Exploring Gen AI), 2025-10-15. https://www.martinfowler.com/articles/exploring-gen-ai/sdd-3-tools.html. Accessed 2026-10-13.
**URL:** https://www.martinfowler.com/articles/exploring-gen-ai/sdd-3-tools.html
**Date accessed:** 2026-10-13
**Evidence level:** 7 (expert hands-on analysis)
**Research topic area:** PM / planning: how Matt Pocock structures work for agents (PRD/spec, grilling, tracer-bullet tickets, HITL/AFK labels, triage, TDD loop) and how it relates to established methods and to borg

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|---------------|
| 1 | Authority | 9/10 | Thoughtworks Distinguished Engineer, published on martinfowler.com. |
| 2 | Evidence Quality | 5/10 | Hands-on trial of three tools with small tasks; no data. |
| 3 | Currency | 9/10 | Oct 2025. |
| 4 | Intent | 8/10 | Analytic, vendor-neutral. |
| 5 | Bias & Objectivity | 8/10 | Reports shortcomings of each tool. |
| 6 | Logic & Coherence | 8/10 | Defines spec-first, spec-anchored, spec-as-source clearly. |
| 7 | Corroboration | 7/10 | Consistent with the Marmelab critique and practitioner questions she cites. |
| 8 | Intellectual Honesty | 8/10 | Says the term is in flux and the practice may not scale. |
| 9 | Specificity | 8/10 | Tool-by-tool findings, including per-change branching in spec-kit. |
| 10 | Relevance | 7/10 | Gives the vocabulary to place Matt's PRD in the spec-first tier. |

**Score band:** keep (weighted average about 7.65).

## Bias Guard Check

- [ ] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [x] Neutral / no strong reaction

## Key Findings

- All spec-driven approaches she found are spec-first; few aim to be spec-anchored (spec kept over time) or spec-as-source.
- She treats spec-kit as spec-first only, with a spec living for one change request, not a feature.
- She notes that carefully crafting a spec first for the agent is valuable in many situations and a top practitioner question.
- Matt's /to-spec fits the spec-first tier, and his doc-rot warning is a spec-lifetime rule: close stale PRDs rather than anchoring to them.

## Verified Quote(s)

**Location reference:** Section 'Spec-first' (the paragraph starting 'All SDD approaches'), under 'What is Spec-driven development?'.

> All SDD approaches and definitions I’ve found are spec-first, but not all strive to be spec-anchored or spec-as-source.

**Access status:** live

## Inclusion Decision

**Decision:** Core
**Rationale:** Independent institutional-grade framing that places PRD-first workflows, including Matt's, in the established vocabulary.

**Redundancy check:** Supplies the taxonomy that no other kept source gives.

**Perspective category:** Institutional
