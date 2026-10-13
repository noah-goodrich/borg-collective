# Source: arXiv 2601.04748, single agent with skills vs multi-agent

**Full citation:** Li, Xiaoxiao. "When Single-Agent with Skills Replace Multi-Agent Systems and When They Fail." arXiv:2601.04748, 2026-01-08. https://arxiv.org/abs/2601.04748
**URL:** https://arxiv.org/abs/2601.04748
**Date accessed:** 2026-10-13
**Evidence level:** 3 (preprint, quantitative; not peer reviewed per the abstract page)
**Research topic area:** Skills vs multi-agent orchestration trade-off (native subagents/workflows vs skill libraries)

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|---------------|
| 1 | Authority | 6/10 | Single-author preprint |
| 2 | Evidence Quality | 6/10 | "Preliminary experiments" |
| 3 | Currency | 9/10 | Jan 2026 |
| 4 | Intent | 9/10 | Research |
| 5 | Bias & Objectivity | 7/10 | Frames open questions |
| 6 | Logic & Coherence | 8/10 | Compile multi-agent to skills |
| 7 | Corroboration | 7/10 | Shadowing paper agrees |
| 8 | Intellectual Honesty | 8/10 | Calls results preliminary |
| 9 | Specificity | 6/10 | Abstract-level detail only |
| 10 | Relevance | 7/10 | Indirect to Claude Code |

- Authority: single author, preprint server only; no verified affiliation was captured.
- Evidence Quality: the abstract itself says "preliminary experiments" on reasoning benchmarks, not coding tasks.
- Currency: January 2026, within the skill-ecosystem period.
- Intent: academic.
- Bias: asks the scaling question rather than selling skills.
- Logic: treats skills as internalized agent behaviors, so a multi-agent system compiles to a single agent trading communication for selection.
- Corroboration: the ICML workshop paper reports the same direction.
- Honesty: flags the work as opening questions.
- Specificity: only the abstract was read here; full text not reviewed.
- Relevance: abstract-level conceptual support for "skills versus multiple agents".

**Score band:** borderline

## Bias Guard Check

- [ ] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [x] Neutral / no strong reaction

## Key Findings

- The paper argues that a single agent selecting from skills can approximate a multi-agent system with less token use and latency, on reasoning benchmarks.
- Skill-selection accuracy stays stable up to a critical library size and then drops sharply, a phase-transition pattern.
- Semantic confusability among similar skills, not just library size, plays a central role in the drop.
- Hierarchical routing is proposed and shown preliminarily to help; Matt's `ask-matt` router skill is a practitioner-built analogue.
- Evidence only from the abstract; confidence in transfer to coding agents is low.

## Verified Quote(s)

**Location reference:** Abstract, sentences 6 to 7 (after "we propose that LLM skill selection exhibits bounded capacity analogous to human decision-making").

> Rather than degrading gradually, selection accuracy remains stable up to a critical library size, then drops sharply

**Access status:** live

## Inclusion Decision

**Decision:** Supporting
**Rationale:** Borderline on authority and evidence; included as gap-fill since peer-reviewed or large-scale evidence on skill libraries does not exist. This is the lowest-scoring card that cleared the bar in this track.

**Redundancy check:** Overlaps the ICML card on direction; adds the phase-transition and confusability claim.

**Perspective category:** Academic
