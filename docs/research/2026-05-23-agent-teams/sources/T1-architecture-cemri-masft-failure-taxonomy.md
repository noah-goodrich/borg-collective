# Source: Cemri et al. — Why Do Multi-Agent LLM Systems Fail? (MASFT)

**Full citation:** Cemri, M., Pan, M. Z., Yang, S., Agrawal, L. A., Chopra, B., Tiwari, R.,
Keutzer, K., Parameswaran, A., Klein, D., Ramchandran, K., Zaharia, M., Gonzalez, J. E.,
& Stoica, I. "Why Do Multi-Agent LLM Systems Fail?" arXiv:2503.13657, March 2025
(updated 2025; NeurIPS 2025 Datasets & Benchmarks Track).
**URL:** https://arxiv.org/abs/2503.13657 (HTML: https://arxiv.org/html/2503.13657v1)
**Date accessed:** 2026-05-23
**Evidence level:** 3 (Large-scale observational — grounded-theory study with
inter-annotator agreement)
**Research topic area:** T1 — Multi-agent team structures (failure modes); T6 — Anti-patterns

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|---------------|
| 1 | Authority | 9/10 | UC Berkeley + collaborators including Matei Zaharia, Ion Stoica, Joseph Gonzalez — top systems / ML researchers. Accepted into NeurIPS 2025 Datasets & Benchmarks Track. |
| 2 | Evidence Quality | 8/10 | First systematic taxonomy with grounded-theory methodology, six expert annotators, 150+ traces, Cohen's Kappa 0.88 for human annotators (0.77 for LLM-as-judge). Limitation: open-source MASs only (ChatDev, AG2/MetaGPT, etc.), no frontier-vendor systems. |
| 3 | Currency | 10/10 | March 2025, the canonical MAS failure-mode reference for 2025–2026 work. |
| 4 | Intent | 9/10 | Academic, open-source dataset, no commercial product. Pure research contribution. |
| 5 | Bias & Objectivity | 8/10 | Names both failures and partial remediation. Doesn't strawman MAS — notes "we do not claim MASFT covers every potential failure pattern." Acknowledges that interventions helped (+14%) but didn't fully fix things. |
| 6 | Logic & Coherence | 8/10 | Methodology section is explicit. Taxonomy maps cleanly to the empirical observations. Logical leap from "open-source MAS frameworks fail at these rates" to "MAS in general" is acknowledged. |
| 7 | Corroboration | 8/10 | Aligned with Cognition's qualitative claims. Anthropic's results suggest carefully-engineered MAS can buck the trend. The arxiv work has been cited extensively in late-2025/2026 agent literature. |
| 8 | Intellectual Honesty | 9/10 | Open dataset and annotations. Explicitly states best-effort prompt interventions don't fully solve the problem; argues for structural redesign. Notes intervention only got ChatDev to ~39% correctness — still unfit for deployment. |
| 9 | Specificity | 9/10 | 14 named failure modes in 3 categories, frequency percentages, named MAS frameworks, concrete failure-trace examples in appendices. Reproducible. |
| 10 | Relevance | 8/10 | Directly addresses why naive multi-agent architectures fail. Slightly less direct for Noah's GTM context (no GTM agents studied) but the failure-mode taxonomy generalizes. |

**Composite score:**
9×0.25 + 8×0.20 + 10×0.10 + 9×0.10 + 8×0.10 + 8×0.05 + 8×0.05 + 9×0.05 + 9×0.05 + 8×0.05
= 2.25 + 1.60 + 1.00 + 0.90 + 0.80 + 0.40 + 0.40 + 0.45 + 0.45 + 0.40 = **8.65**

## Bias Guard Check

- [ ] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [x] Neutral / no strong reaction

(The paper is methodologically careful and I have no strong prior either way on whether
open-source MAS frameworks should hit 25–75% failure rates.)

## Key Findings

1. **14 failure modes organized into 3 categories:** (i) specification and system design
   failures, (ii) inter-agent misalignment, (iii) task verification and termination. First
   empirically grounded taxonomy of MAS failures.
2. **MAS performance gains over single-agent are minimal on popular benchmarks.** ChatDev
   correctness can be as low as 25% (Figure 1). Other frameworks fail 41–86.7% of the time.
3. **Best-effort prompt-engineering interventions are not enough.** Authors tried better
   specifications and orchestration; got +14% on ChatDev but still well below
   deployment-ready.
4. **Many MAS failures arise from inter-agent interaction, not individual model limitations.**
   Argues for borrowing from High Reliability Organization (HRO) theory — organizational
   design matters as much as agent capability.
5. **Three frameworks studied (ChatDev, AG2/MetaGPT) are open-source.** Findings may not
   directly apply to closely-engineered vendor systems (Anthropic Research, OpenAI Operator)
   but the failure modes are framework-agnostic.

## Verified Quote(s)

**Location reference:** Abstract, paragraph 1; Section 1 Introduction, paragraph 3
(post-Figure 1) and the contributions bullets.

> "Despite growing enthusiasm for Multi-Agent Systems (MAS), where multiple LLM agents
> collaborate to accomplish tasks, their performance gains across popular benchmarks remain
> minimal compared to single-agent frameworks."

> "We identify 14 unique failure modes and propose a comprehensive taxonomy applicable to
> various MAS frameworks. This taxonomy emerges iteratively from agreements among three
> expert annotators per study, achieving a Cohen's Kappa score of 0.88. These fine-grained
> failure modes are organized into 3 categories: (i) specification and system design
> failures, (ii) inter-agent misalignment, and (iii) task verification and termination."

> "Our empirical analysis reveals that the correctness of the state-of-the-art (SOTA)
> open-source MAS, ChatDev (Qian et al., 2023), can be as low as 25%, as shown in Fig. 1."

**Access status:** live

## Inclusion Decision

**Decision:** Core
**Rationale:** Strong Include (Rule 1). Composite 8.65, top of the corpus. Anchors the
academic perspective for T1 and T6. Without this, the failure-mode discussion is
practitioner-anecdotal only.

**Redundancy check:** Adjacent to Cognition's contrarian post but provides the rigorous
empirical backing Cognition lacks. Both kept; they corroborate from different evidence
types.

**Perspective category:** Academic
