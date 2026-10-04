# Source: The SPACE of Developer Productivity (full text, ACM Queue)

**Full citation:** Forsgren, N., Storey, M.-A., Maddila, C., Zimmermann, T., Houck, B., Butler, J. "The SPACE of
Developer Productivity: There's more to it than you think." ACM Queue 19(1), Jan-Feb 2021 (also CACM 64(6)).
DOI 10.1145/3454122. Published 6 March 2021.
**URL:** https://queue.acm.org/detail.cfm?id=3454124
**Date accessed:** 2026-10-03
**Evidence level:** 7 (Expert opinion / framework synthesis; downgraded from 4 on full-text read: the article reports
no new empirical test of its own)
**Research topic area:** SPACE framework; developer productivity measurement (T3 flow, RQ3)

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|---------------|
| 1 | Authority | 9/10 | Forsgren (DORA), Storey (Univ. of Victoria, Canada Research Chair) plus four Microsoft Research staff. |
| 2 | Evidence Quality | 4/10 | Framework drawn from 22 references; no new data or test of whether SPACE improves outcomes. |
| 3 | Currency | 6/10 | March 2021 (5.5 years old); framework still widely used, anti-single-metric logic is durable. |
| 4 | Intent | 8/10 | Practitioner-research article in ACM Queue; authors work for the vendors whose teams it describes. |
| 5 | Bias & Objectivity | 7/10 | Argues one thesis (multi-metric) but lists failure modes of its own metrics (retention, story points). |
| 6 | Logic & Coherence | 7/10 | Myths, then dimensions, then usage rules is coherent; "at least three" is asserted, not derived. |
| 7 | Corroboration | 8/10 | DORA pitfalls, Beck/Orosz critique and Goodhart sources make the same anti-single-metric point. |
| 8 | Intellectual Honesty | 8/10 | "No metric can ever be a perfect proxy"; names privacy, bias and over-measurement risks. |
| 9 | Specificity | 7/10 | Concrete example metrics per dimension and level; the 3-dimension threshold is a rule of thumb. |
| 10 | Relevance | 9/10 | Says individuals can track their own productivity; perceptual metrics; metrics signal what is valued. |

**Score band:** keep
(Intermediate weighted average ~7.1, marginal. It was borderline ~6.9 on the abstract alone; the full text raised
Honesty, Specificity and Relevance, while Evidence Quality stayed at 4. This keep rests on Authority and Relevance,
not on evidence strength.)

## Bias Guard Check

- [ ] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [x] Neutral / no strong reaction

## Key Findings

- Five myths are rebutted: productivity is not just activity, not just individual performance, not one metric, not
  useful only to managers, and not only tools. Activity counts "should never be used in isolation either to reward
  or to penalize developers".
- SPACE = Satisfaction and well-being; Performance; Activity; Communication and collaboration; Efficiency and flow.
  Performance is "best evaluated as outcomes instead of output".
- Usage rules: capture metrics from at least three dimensions, include at least one perceptual (survey) measure,
  and expect metrics "in tension" by design. A handful is enough; too many "may also lead to confusion and lower
  motivation".
- Metrics signal what is valued and shape behaviour; adding or removing a metric nudges behaviour. Story points
  alone push people to optimise their own points at the expense of invisible work.
- Individual use is endorsed when opt-in: developers "have found value in tracking their own productivity", and
  satisfaction may be a leading indicator of burnout (retention is called a lagging, noisy proxy).
- Not shown: any empirical evidence that adopting SPACE improves outcomes; this is a framework, not a trial.

## Verified Quote(s)

**Location reference:** ACM Queue article page: section "How to Use the Framework" (first and second paragraphs);
section "What to Watch For" (first and second paragraphs); introduction, paragraph beginning "This article explicates
several common myths".

> To measure developer productivity, teams and leaders (and even individuals) should capture several metrics across multiple dimensions of the framework—at least three are recommended.

> Another recommendation is that at least one of the metrics include perceptual measures such as survey data.

> Having too many metrics may also lead to confusion and lower motivation; not all dimensions need to be included for the framework to be helpful.

> Any measurement paradigm should be used carefully because no metric can ever be a perfect proxy.

> The most important takeaway from exposing these myths is that productivity cannot be reduced to a single dimension (or metric!).

**Access status:** cached/partial
**Access note:** full text read from a user-supplied copy on 2026-10-03; the live URL is bot-blocked (HTTP 403 to
automated fetch). The copy is a browser save of queue.acm.org/doi/10.1145/3454122.3454124 (same host as the card
URL). Status is cached/partial rather than live because the verifier cannot re-fetch it unaided.

## Inclusion Decision

**Decision:** Core
**Rationale:** Standard reference for multi-dimensional productivity measurement and the one framework-level source in
the track. Band is keep but marginal (a candidate for "lowest keep" in this batch): the evidence is conceptual, so
cite it for design principles (multiple dimensions, perceptual data, metrics shape behaviour), not as proof that any
metric set works.

**Redundancy check:** Not redundant with the DORA cards (system delivery metrics); it supplies the
satisfaction/perceptual and "metrics in tension" arguments. The Azure blog card (t5-space-forsgren-azure-blog) is a
secondary summary and this card supersedes it for quotes.

**Perspective category:** Academic
