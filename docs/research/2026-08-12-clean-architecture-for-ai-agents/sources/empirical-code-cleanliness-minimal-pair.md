# Source: Does Code Cleanliness Affect Coding Agents? (SonarSource Minimal-Pair Study)

**Full citation:** Trivedi, Priyansh; Schmitt, Olivier (SonarSource). "Does Code Cleanliness Affect
Coding Agents? A Controlled Minimal-Pair Study." arXiv:2605.20049. May 19, 2026.
**URL:** https://arxiv.org/abs/2605.20049
**Date accessed:** 2026-08-12
**Evidence level:** 3 (controlled quasi-experimental study; preprint, not peer-reviewed)
**Research topic area:** Empirical & academic evidence — codebase structure vs. agent performance
(null-result / nuance angle)

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|----------------|
| 1 | Authority | 6/10 | SonarSource is a recognized static-analysis/code-quality vendor with direct subject-matter expertise in the constructs being measured (rule violations, cognitive complexity); this is industry research, not peer-reviewed academia. |
| 2 | Evidence Quality | 8/10 | Minimal-pair design (repositories matched on architecture/dependencies/behavior, differing only in cleanliness), 33 tasks x 6 pairs, 660 total trials with Claude Code, hidden application-level tests. Strong isolation of the treatment variable for a preprint. |
| 3 | Currency | 9/10 | Published May 2026, current to this fast-moving literature. |
| 4 | Intent | 6/10 | SonarSource sells code-quality tooling and has a commercial interest in "cleanliness matters" being true; tempered by the fact the headline correctness result is null, which cuts against pure marketing framing. |
| 5 | Bias & Objectivity | 7/10 | Publishing a null result on their own product's core value proposition (pass-rate improvement) despite commercial incentive to find otherwise is a credible objectivity signal. |
| 6 | Logic & Coherence | 8/10 | The minimal-pair construction (degrading clean repos AND cleaning messy ones, in both directions) is a coherent way to isolate cleanliness from confounds like inherent task difficulty. |
| 7 | Corroboration | 6/10 | Corroborates the direction (not magnitude) of "Constraint Decay" (arXiv:2605.06445) in that structural properties don't straightforwardly buy higher correctness; diverges from the positive-navigation framing in "Formal Architecture Descriptors" (arXiv:2604.13108). |
| 8 | Intellectual Honesty | 8/10 | Reports "no effect on pass rate" as the headline finding rather than emphasizing only the efficiency wins, which would have been the more marketable framing. |
| 9 | Specificity | 9/10 | Precise, falsifiable numbers: 7-8% token reduction, 34% fewer file revisitations, 0 measurable pass-rate delta across 660 trials. |
| 10 | Relevance | 7/10 | On-topic but scoped to code cleanliness (linting rules, cognitive complexity) rather than architectural layering/abstraction depth specifically — adjacent to, not identical with, this track's core question. |

**Score band:** keep

## Bias Guard Check
- [ ] I agree with this source's conclusions -> scored harder on dims 5, 6, 8
- [x] I disagree with this source's conclusions -> scored more generously on dims 5, 6, 8
- [ ] Neutral / no strong reaction

(A null result on correctness cuts against the assumption that structural discipline reliably
improves agent output quality — noted per the guard rather than discounted.)

## Key Findings
- Across 660 trials (33 tasks x 6 minimal repository pairs) run with Claude Code, code cleanliness
  (static-analysis rule violations, cognitive complexity) produced no measurable change in the
  agent's task pass rate.
- Code cleanliness did substantially change the agent's *operational footprint*: agents working
  on cleaner code used 7-8% fewer tokens on average.
- Agents working on cleaner code reduced file revisitations by 34%, indicating cleanliness
  primarily affects navigational efficiency, not correctness.
- Minimal pairs were constructed bidirectionally (degrading clean repos via an agent pipeline, and
  cleaning messy repos via the same pipeline) to control for confounds like inherent task
  difficulty or pre-existing architectural quality.
- The authors conclude traditional maintainability principles remain relevant in AI-driven
  development — but explicitly reframe *why*: as a cost/efficiency lever, not a correctness lever.

## Verified Quote(s)

**Location reference:** Abstract / results summary (verified via WebFetch of arxiv.org/abs/2605.20049).

> "code cleanliness does not change the agent's pass rate"

**Access status:** live

## Inclusion Decision
**Decision:** Supporting
**Rationale:** This is the strongest available evidence that the relationship between codebase
structure and agent performance is not a simple "cleaner/more structured = higher success rate"
story — it decouples correctness from efficiency, which materially complicates the pro-Clean-
Architecture practitioner narrative found elsewhere in this track without going as far as the
Constraint Decay paper's negative finding.
**Redundancy check:** Not redundant — this is the only source measuring "cleanliness" (lint
rules/complexity) as opposed to "layering" (Constraint Decay) or "navigation aids" (Formal
Architecture Descriptors); it adds a distinct, non-overlapping construct and a genuinely null
result that neither confirms nor rebuts the layering-specific findings.
**Perspective category:** Academic

---
