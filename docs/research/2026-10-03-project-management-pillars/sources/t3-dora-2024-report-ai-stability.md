# Source: DORA 2024 Accelerate State of DevOps: AI adoption vs delivery throughput/stability

**Full citation:** DORA / Google Cloud. "Announcing the 2024 DORA report." Google Cloud Blog. 2024-10-22.
**URL:** https://cloud.google.com/blog/products/devops-sre/announcing-the-2024-dora-report
**Date accessed:** 2026-10-03
**Evidence level:** 3 (Large-scale observational / survey)
**Research topic area:** DORA four keys; AI-assisted delivery (T3 flow)

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|---------------|
| 1 | Authority | 8/10 | DORA is the longest-running delivery-performance research programme (since 2014), but this is a vendor blog summarising the report, not the report itself. |
| 2 | Evidence Quality | 6/10 | Large annual survey (sample size not stated on the blog post); cross-sectional, self-reported, so associations not causation. Model estimates are stated as 'estimated'. |
| 3 | Currency | 8/10 | Oct 2024; a 2025 follow-up supersedes the AI sign of the throughput effect. |
| 4 | Intent | 5/10 | Google Cloud publishes it and sells AI/DevOps tooling; mixed research/marketing intent. |
| 5 | Bias & Objectivity | 5/10 | Frames AI as 'impacts' delivery; sponsor has an AI product interest, though the headline here is a negative result. |
| 6 | Logic & Coherence | 6/10 | Conclusion 'fundamentals like small batches still matter' is a reasonable but untested inference. |
| 7 | Corroboration | 7/10 | Echoed by the 2025 report (stability still negative), Faros telemetry, and independent reviews. |
| 8 | Intellectual Honesty | 6/10 | States the surprising negative result plainly rather than burying it. |
| 9 | Specificity | 7/10 | Gives per-25%-adoption estimates: -1.5% throughput, -7.2% stability. |
| 10 | Relevance | 9/10 | Direct evidence on AI adoption and the four-keys outcomes. |

**Score band:** borderline
(Intermediate weighted average ~6.8; the band is the disposition.)

## Bias Guard Check

- [ ] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [x] Neutral / no strong reaction

## Key Findings

- Each 25% increase in AI adoption was associated with an estimated 1.5% decrease in delivery throughput and 7.2% decrease in delivery stability (2024 survey).
- DORA's own interpretation: improving the development process does not automatically improve delivery without the basics, specifically small batch sizes and robust testing.
- AI adoption was associated with individual-level benefits (productivity, flow, satisfaction) while worsening system-level delivery: local vs global optimisation.
- Associations come from self-reported cross-sectional survey data; see the Lee critique card for limits.

## Verified Quote(s)

**Location reference:** https://cloud.google.com/blog/products/devops-sre/announcing-the-2024-dora-report, section "AI:
Benefits, challenges, and developing trust", paragraph 4 (counting body paragraphs after the heading, excluding the
three-item list; it begins "However, despite AI\x27s potential benefits"); both quotes are in this paragraph.

Card revised: 2026-10-03 (location audit before re-verification)

> As AI adoption increased, it was accompanied by an estimated decrease in delivery throughput by 1.5%, and an estimated reduction in delivery stability by 7.2%.

> improving the development process does not automatically improve software delivery — at least not without proper adherence to the basics of successful software delivery, like small batch sizes and robust testing mechanisms

**Access status:** live

## Inclusion Decision

**Decision:** Core
**Rationale:** (Band borderline: retained as gap-fill or sole source, named here.) Primary evidence for the 2024 AI-stability finding and the small-batches prescription. Superseded in sign (throughput) by the 2025 card, retained for the trajectory.

**Redundancy check:** Pairs with, does not duplicate, the 2025 card: the change between years is itself a finding.

**Perspective category:** Institutional
