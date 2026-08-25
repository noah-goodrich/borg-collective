# Source: Does Code Cleanliness Affect Coding Agents? A Controlled Minimal-Pair Study (SonarSource / arXiv)

**Full citation:** Trivedi, Priyansh; Schmitt, Olivier (SonarSource). "Does Code Cleanliness Affect Coding
Agents? A Controlled Minimal-Pair Study." arXiv:2605.20049. May 19, 2026.
**URL:** https://arxiv.org/abs/2605.20049
**Date accessed:** 2026-08-12
**Evidence level:** 5 (Practitioner Case Study w/ Data — a controlled minimal-pair experiment; arXiv
preprint, industry-authored, NOT peer-reviewed, single agent/model tested)
**Research topic area:** Practitioner discourse on agent-ready codebases (empirical corroboration)

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|----------------|
| 1 | Authority | 7/10 | Authored by researchers at SonarSource, an established static-analysis/code-quality company (makers of SonarQube) with direct domain expertise in code cleanliness metrics; not a university, and not peer-reviewed. |
| 2 | Evidence Quality | 9/10 | Controlled minimal-pair design (repositories matched on architecture/dependencies, differing only in static-analysis violations and cognitive complexity), 33 tasks x 6 repository pairs = 660 trials with hidden application-level tests — the strongest experimental design found in this track. |
| 3 | Currency | 9/10 | Preprint dated May 19, 2026, squarely current; findings are tied to one model generation (Claude Code) and will need re-validation as models change, which caps rather than boosts long-term durability. |
| 4 | Intent | 6/10 | Genuine research intent, but SonarSource's commercial product (static-analysis/code-quality tooling) benefits from a finding that code cleanliness matters — a real, if mild, conflict of interest. |
| 5 | Bias & Objectivity | 8/10 | Notably reports a null/unfavorable result (no significant pass-rate difference from cleaner code) rather than only the favorable efficiency numbers, which cuts against the commercial-bias concern. |
| 6 | Logic & Coherence | 9/10 | Rigorous factorial minimal-pair methodology isolates cleanliness as the manipulated variable while holding architecture and dependencies constant. |
| 7 | Corroboration | 7/10 | Empirically supports the token/navigation-efficiency mechanism both Akita and Miller invoke qualitatively; a separate arXiv paper on "Constraint Decay" (arXiv:2605.06445, found by a parallel research track) corroborates this study's null pass-rate finding while directly testing Clean Architecture and finding it can reduce pass rate — a useful cross-track tension to flag. |
| 8 | Intellectual Honesty | 9/10 | Explicitly states cleanliness "does not change the agent's pass rate," resisting the temptation to inflate a null primary result by burying it under the efficiency headline. |
| 9 | Specificity | 10/10 | Exact, falsifiable numbers: 7-8% token reduction, 34% fewer file revisitations, 660 trials, 33 tasks, 6 repository pairs. |
| 10 | Relevance | 8/10 | Directly relevant to the "structure/cleanliness affects agent performance" question this track investigates, though it tests code-quality/complexity metrics rather than macro-architecture (Clean Architecture layering) specifically — narrower scope than the track's core architectural question. |

**Score band:** keep

## Bias Guard Check
- [ ] I agree with this source's conclusions -> scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions -> scored more generously on dims 5, 6, 8
- [x] Neutral / no strong reaction

## Key Findings
- Across 660 trials of Claude Code on 33 tasks spanning six matched repository pairs, code cleanliness
  produced no statistically significant difference in task pass rate — agents succeeded or failed at
  roughly the same rate on clean vs. messy code.
- Cleaner code did substantially change HOW agents worked: a 7-8% reduction in token usage and a 34%
  reduction in file revisitations compared to the messy-code condition.
- The minimal-pair methodology (matching on architecture and dependencies, varying only static-analysis
  violations and cognitive complexity) isolates cleanliness as a cost/efficiency lever distinct from a
  correctness lever — a nuance most qualitative practitioner pieces in this track do not distinguish.
- The authors conclude that traditional maintainability principles remain relevant in the AI-agent era, but
  reframe their payoff: not higher success rates, but lower computational cost and fewer wasted navigation
  steps per task.
- This is an arXiv preprint, not peer-reviewed, and tests a single agent/model (Claude Code) — the
  quantitative findings should not be over-generalized to other agents or to macro-architectural patterns
  like Clean Architecture, which this study does not manipulate directly (see the separate Constraint Decay
  study for a direct architectural-pattern test).

## Verified Quote(s)

**Location reference:** Abstract and results section of the arXiv preprint (2605.20049).

> "Does Code Cleanliness Affect Coding Agents? A Controlled Minimal-Pair Study"

> "code cleanliness does not change the agent's pass rate"

> "agents working on cleaner code use 7 to 8% fewer tokens and reduce file revisitations by 34%"

**Access status:** live

## Inclusion Decision
**Decision:** Supporting
**Rationale:** The one source in this track with a genuinely controlled, quantified experimental design;
it grounds the qualitative "structure helps agents" claims made by Akita, Böckeler, and NimblePros in
measured token/navigation numbers, while its honest null result on pass rate is a useful check against
overclaiming.
**Redundancy check:** No other kept source in this track offers quantitative, controlled data; this is the
only Evidence-Level-5 source among six kept/borderline cards, all others being Level 7-8 opinion/anecdote.
**Perspective category:** Academic

---
