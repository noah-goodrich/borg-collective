# Source: DORA 2025 State of AI-assisted Software Development

**Full citation:** DORA / Google Cloud. "Announcing the 2025 DORA Report." Google Cloud Blog. 2025-09-23.
**URL:** https://cloud.google.com/blog/products/ai-machine-learning/announcing-the-2025-dora-report
**Date accessed:** 2026-10-03
**Evidence level:** 3 (Large-scale observational / survey)
**Research topic area:** DORA four keys; AI-assisted delivery (T3 flow)

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|---------------|
| 1 | Authority | 8/10 | DORA research programme (Google Cloud); blog authors summarise the report, which is the true primary. |
| 2 | Evidence Quality | 6/10 | Survey of nearly 5,000 professionals plus 100+ hours of qualitative data; cross-sectional, self-reported. |
| 3 | Currency | 10/10 | Sept 2025, about a year before access. |
| 4 | Intent | 5/10 | Product launch post; Google sells AI and platform tooling. |
| 5 | Bias & Objectivity | 5/10 | Uses an 'amplifier' framing that flatters platform investment (the sponsor's product area). |
| 6 | Logic & Coherence | 6/10 | Claims follow from the survey model; the 'confirms our central theory' phrasing is stronger than a correlation supports. |
| 7 | Corroboration | 7/10 | Faros telemetry, Scrum.org/other summaries and METR perception-gap data point the same way. |
| 8 | Intellectual Honesty | 6/10 | Explicitly says the negative stability relationship persists; hedges 'It appears that...'. |
| 9 | Specificity | 6/10 | Qualitative direction given, fewer numbers on the blog than the full report. |
| 10 | Relevance | 9/10 | Directly on AI and delivery throughput/stability. |

**Score band:** borderline
(Intermediate weighted average ~6.9; the band is the disposition.)

## Bias Guard Check

- [ ] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [x] Neutral / no strong reaction

## Key Findings

- In 2025 DORA observed a positive relationship between AI adoption and both delivery throughput and product performance, reversing 2024's throughput sign.
- AI adoption still has a negative relationship with delivery stability, which DORA says confirms that AI accelerates development but exposes downstream weaknesses.
- DORA recommends robust automated testing, mature version control and fast feedback loops as the control systems that keep AI acceleration from degrading stability.
- Central framing: AI is an amplifier of existing team strengths and dysfunctions, a claim stated as a theory, not an experiment.

## Verified Quote(s)

**Location reference:** https://cloud.google.com/blog/products/ai-machine-learning/announcing-the-2025-dora-report,
section "AI, the great amplifier", paragraph 1 (beginning "As we established from the 2024 report"); both quotes are in
this paragraph ("Unlike last year, we observe..." is its third sentence, not the start of the paragraph as the earlier
reference said).

Card revised: 2026-10-03 (location audit before re-verification)

> Unlike last year, we observe a positive relationship between AI adoption on both software delivery throughput and product performance.

> AI adoption does continue to have a negative relationship with software delivery stability.

**Access status:** live

## Inclusion Decision

**Decision:** Core
**Rationale:** (Band borderline: retained as gap-fill or sole source, named here.) Most current institutional evidence on AI and delivery metrics; directly relevant to a solo operator using AI agents.

**Redundancy check:** Complements the 2024 card; same sponsor so not independent of it.

**Perspective category:** Institutional
