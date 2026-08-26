# Source: Constraint Decay — Clean Architecture Directly Tested and Penalized

**Full citation:** Dente, Francesco; Satriani, Dario; Papotti, Paolo. "Constraint Decay: The Fragility of
LLM Agents in Backend Code Generation." arXiv:2605.06445. May 7, 2026.
**URL:** https://arxiv.org/abs/2605.06445
**Date accessed:** 2026-08-12
**Evidence level:** 3 (controlled quasi-experimental study; preprint, not peer-reviewed)
**Research topic area:** Empirical & academic evidence — codebase structure vs. agent performance
(contrarian angle)

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|----------------|
| 1 | Authority | 7/10 | Authors are affiliated with EURECOM (France) and the University of Basilicata (Italy); Paolo Papotti is an established academic in data/AI systems. Preprint, not yet peer-reviewed. |
| 2 | Evidence Quality | 8/10 | Factorial design across four independently manipulated constraint dimensions (framework, architectural pattern, database, ORM), 100 tasks across 8 frameworks, dual evaluation (behavioral tests + static verifiers). Rigorous for a preprint; loses points only for lack of peer review. |
| 3 | Currency | 9/10 | Published May 2026, squarely inside the Claude-Code-era agent literature this track targets. |
| 4 | Intent | 9/10 | Pure academic inquiry into agent fragility under constraints; no product or tool being sold. |
| 5 | Bias & Objectivity | 8/10 | Reports an uncomfortable, non-marketable finding (imposing Clean Architecture measurably hurts pass rate) with no apparent motive to shade it either direction. |
| 6 | Logic & Coherence | 8/10 | Clean causal design: constraint levels (L0 baseline -> L3 fully specified) let the paper isolate the effect of each dimension, including "Clean architecture" as its own row in Table 3(a). |
| 7 | Corroboration | 7/10 | Aligns with the SonarSource minimal-pair study's null finding on correctness (arXiv:2605.20049 — structure doesn't reliably buy you a higher pass rate) and directly tensions with the positive framing in "Formal Architecture Descriptors" (arXiv:2604.13108). |
| 8 | Intellectual Honesty | 8/10 | Publishes a finding that runs against the popular "clean architecture helps agents" narrative rather than softening it. |
| 9 | Specificity | 9/10 | Exact effect size reported: "Clean architecture −9.1±1.6" percentage points on assertion pass rate; aggregate −30 points from baseline to fully constrained tasks across capable configurations. |
| 10 | Relevance | 10/10 | This is the only source found in this track that names "Clean Architecture" as an explicitly manipulated experimental variable and reports a quantified effect on agent success rate — a direct, load-bearing test of this track's core question. |

**Score band:** keep

## Bias Guard Check
- [x] I disagree with this source's conclusions -> scored more generously on dims 5, 6, 8
- [ ] I agree with this source's conclusions -> scored harder on dims 5, 6, 8
- [ ] Neutral / no strong reaction

(Noted: this finding cuts against the instinct that "more architectural discipline = better AI-agent
outcomes," which is the popular assumption in most practitioner content surveyed for this track. Flagging
per the guard rather than discounting the paper's rigor.)

## Key Findings
- Across 8 web frameworks and 100 generation/feature-implementation tasks, imposing a mandated
  four-layer Clean Architecture pattern (routes/handlers, services/use cases, models/entities,
  repository/data access, with strict top-down dependency rules) reduced assertion pass rate by
  9.1 ± 1.6 percentage points relative to unconstrained baseline generation.
- Capable model configurations lost an average of 30 points in assertion pass rate moving from
  baseline (no structural constraints) to fully specified tasks (architecture + database + ORM
  constraints combined) — the paper's named "constraint decay" phenomenon.
- Database-layer constraints, not architectural pattern, were the single largest driver of the
  decay — data-layer defects (incorrect query composition, ORM violations) were the leading
  failure cause, meaning Clean Architecture's penalty is real but not the dominant one.
- Framework convention-weight mattered: agents performed measurably worse in convention-heavy
  frameworks (FastAPI, Django) than in minimal ones (Flask), suggesting structural expectations
  themselves — independent of "cleanliness" — are a tax on agent success.
- Weaker model configurations approached near-zero success under full specification, meaning the
  structural penalty compounds with model capability rather than being a fixed cost.

## Verified Quote(s)

**Location reference:** Table 3(a), constraint-dimension ablation results section.

> "Clean architecture −9.1±1.6"

**Access status:** live (verified via WebFetch of the arXiv HTML full text, arxiv.org/html/2605.06445v1)

## Inclusion Decision
**Decision:** Core
**Rationale:** This is the single most directly on-topic, most rigorous, and most consequential
source this track found. It is the only study that operationalizes "Clean Architecture" as a
named, manipulated variable in a controlled experiment and reports its causal effect on agent
success rate — and that effect is negative. It anchors the contrarian side of this track's
evidence base with real numbers rather than opinion.
**Redundancy check:** No stronger source makes this specific claim. The SonarSource paper
(arXiv:2605.20049) is adjacent (code cleanliness, not layering) and finds a null effect on
correctness; this paper is the first to isolate architectural layering itself and finds a
negative effect. Not redundant with anything else kept in this track.
**Perspective category:** Contrarian

---
