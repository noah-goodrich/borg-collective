# Source: Categorizing Variants of Goodhart's Law (Manheim & Garrabrant)

**Full citation:** Manheim, D., & Garrabrant, S. "Categorizing Variants of Goodhart's Law." arXiv:1803.04585v4 [cs.AI]. 24 Feb 2019. https://arxiv.org/pdf/1803.04585
**URL:** https://arxiv.org/pdf/1803.04585
**Date accessed:** 2026-10-03
**Evidence level:** 7 (Theoretical taxonomy with worked examples; preprint)
**Research topic area:** Goodhart failure modes for value metrics (RQ3)

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|---------------|
| 1 | Authority | 7/10 | Independent researchers affiliated with alignment/forecasting research; preprint not peer-reviewed in a classical journal but widely cited. |
| 2 | Evidence Quality | 4/10 | Conceptual taxonomy with formal notation and illustrative examples, not empirical measurement of how often each mode occurs. |
| 3 | Currency | 7/10 | 2018 preprint, v4 in 2019; the taxonomy is conceptual and durable (+2 applied). |
| 4 | Intent | 9/10 | Academic/research intent; no product to sell. |
| 5 | Bias & Objectivity | 8/10 | Notes that the taxonomy categories overlap and that terminology is ambiguous across Goodhart/Campbell formulations. |
| 6 | Logic & Coherence | 8/10 | Defines a system, a regulator, and a proxy and derives four distinct collapse mechanisms. |
| 7 | Corroboration | 7/10 | The four-way split is used and cited in later AI-safety and metrics literature; Strathern/Campbell lineage supports the core idea. |
| 8 | Intellectual Honesty | 8/10 | States that the categories often co-occur and that the usage of "Goodhart's Law" has become ambiguous. |
| 9 | Specificity | 7/10 | Gives formal definitions and subcategory examples (e.g., teacher/student test proxy) though little software data. |
| 10 | Relevance | 6/10 | Domain is AI/optimization; applies to any metric-as-target value score but requires translation to project management. |

**Score band:** borderline

(Intermediate weighted average 6.8; the band is the disposition.)

## Bias Guard Check

- [ ] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [x] Neutral / no strong reaction

## Key Findings

- Overoptimizing on a metric has several DISTINCT failure modes, so "Goodhart" is not one risk but a family; mitigation
must be matched to the mode.
- Four categories: Regressional (selecting on a noisy proxy also selects for noise), Extremal (pushing the metric into a
region where old relationships fail), Causal (acting on the proxy breaks the causal link), Adversarial (an agent games
it).
- For value-for-effort scoring, regressional is the baseline failure (noisy estimates ranked by score), and adversarial
becomes live when the scorer is also the one rewarded by the score, e.g., an AI agent that can influence its own
metric.
- The paper notes the term has been stretched to the point of ambiguity, so any use should name the specific mechanism.

## Verified Quote(s)

**Location reference:** https://arxiv.org/pdf/1803.04585 (arXiv v4; PDF page numbers; the paper has no section titled
"Introduction"). Quote 1: PDF page 1, the opening paragraph under the author block (the unlabeled abstract), first
sentence. Quote 2: section "Varieties of Goodhart-like Phenomena", paragraph 1 (beginning "As used in this paper, a
Goodhart effect is"), second sentence, which starts on PDF page 1 ("The four categories ... are 1) Regressional ...")
and continues on PDF page 2, where the quoted text "2) Extremal ..." appears. Footnote 1 on page 1 gives the original
formulation.

Card revised: 2026-10-03 (location audit before re-verification)

> There are several distinct failure modes for overoptimization of systems on the basis of metrics.

> 2) Extremal, where selection for the metric pushes the state distribution into a region where old relationships no longer hold, 3) Causal, where an action on the part of the regulator causes the collapse, and 4) Adversarial, where an agent with different goals than the regulator causes the collapse.

**Access status:** live

## Inclusion Decision

**Decision:** Supporting
**Rationale:** Borderline-score source kept as sole formal taxonomy of Goodhart modes; named marginal keep. Conceptual only, so used
to structure RQ3 failure-mode vocabulary, not to claim frequencies.

**Redundancy check:** Adds a taxonomy that practitioner Goodhart blogs lack; they were not carded.

**Perspective category:** Academic
