# Source: AI Engineer World's Fair 2026: Building Great Agent Skills, The Missing Manual

**Full citation:** Matt Pocock. "Building Great Agent Skills: The Missing Manual." AI Engineer World's Fair 2026 (20:43). Talk page with transcript and article. ai.engineer.
**URL:** https://ai.engineer/talks/UNzCG3lw6O0-building-great-agent-skills
**Date accessed:** 2026-10-13
**Evidence level:** 7 (conference talk / thought leadership)
**Research topic area:** WHAT IT IS (primary sources): mattpocock/skills, Sandcastle, AI Hero, Matt's stated philosophy

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|---------------|
| 1 | Authority | 8/10 | Matt's own conference talk, hosted by the AI Engineer organisation; the written article is AI Engineer's derivative rendering of it. |
| 2 | Evidence Quality | 4/10 | Argument and examples from the author's experience; no measured results shown. |
| 3 | Currency | 9/10 | 2026 World's Fair; current with the v1.x skills. |
| 4 | Intent | 7/10 | Conference education. |
| 5 | Bias & Objectivity | 6/10 | Candid trade-off framing (user-invoked versus model-invoked costs), though still advocacy for his method. |
| 6 | Logic & Coherence | 8/10 | Four-part rubric (trigger, structure, steering, pruning) is coherent. |
| 7 | Corroboration | 7/10 | The same ideas appear in the writing-for-agents skill, the README's user-invoked/model-invoked axis, and the Pragmatic Engineer interview. |
| 8 | Intellectual Honesty | 6/10 | States costs of each invocation mode rather than only benefits. |
| 9 | Specificity | 8/10 | Timestamped chapters (0:00, 3:28, 7:22, 11:29, 16:18) and concrete tips. |
| 10 | Relevance | 9/10 | Matt's rubric for what makes a good skill, central to the philosophy track. |

**Score band:** borderline

(Intermediate weighted average about 6.9; the disposition is the band word.)

## Bias Guard Check

- [ ] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [x] Neutral / no strong reaction

## Key Findings

- Matt names 'skill hell', an accumulation of apparent capabilities that does not reliably produce results, and proposes a four-part rubric: trigger, structure, steering, pruning.
- Invocation trade-off: model-invoked skills add context load (each description sits in the context) and selection uncertainty; user-invoked skills add operator cognitive load. This is the rationale for the repo's user-invoked/model-invoked split.
- Structure: organise skills into steps and reference, and put branch-specific templates behind context pointers rather than loading them every invocation.
- Pruning: delete duplicated material, accumulated 'sediment', stale references and no-ops that a deletion test shows do not change behaviour.
- The talk page is AI Engineer's derived write-up of the video, so quotes below are from that page, not the raw transcript.

## Verified Quote(s)

**Location reference:** Quote 1: Article summary under 'Building Great Agent Skills: A Practical Framework for Escaping Skill Hell'; Quote 2: Section 01 'Why more skills do not necessarily produce better agents', first sentence; Quote 3: Section 02 'Choose who bears the burden of invoking a skill', second paragraph

> Matt Pocock explains how to evaluate and improve agent skills through four design concerns: invocation, internal structure, behavioral steering, and disciplined pruning.

> The central problem with agent skills is not scarcity.

> Model invocation increases convenience, but that convenience has a recurring cost.

**Access status:** live

## Inclusion Decision

**Decision:** Core
**Rationale:** Borderline band (just under keep): included as Matt's most structured statement of skill-design philosophy (sole structured source), hosted by a neutral conference org.

**Redundancy check:** Unique on the rubric; the fundamentals talk covers the engineering-practice side.

**Perspective category:** Institutional
