# Source: An empirical study of WIP in kanban teams (ESEM 2018, full text)

**Full citation:** Sjøberg, D. I. K. (sole author; University of Oslo and SINTEF Digital). "An Empirical Study of WIP in
Kanban Teams." Proc. 12th ACM/IEEE International Symposium on Empirical Software Engineering and Measurement (ESEM
'18), Oulu, Finland, 11-12 Oct 2018. DOI 10.1145/3239235.3239238. (The earlier version of this card listed "et al.";
the full text shows one author.)
**URL:** https://dl.acm.org/doi/10.1145/3239235.3239238
**Date accessed:** 2026-10-03
**Evidence level:** 3 (Observational, longitudinal; single company, five teams)
**Research topic area:** WIP limits evidence (T3 flow)

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|---------------|
| 1 | Authority | 8/10 | Peer-reviewed at ESEM; author is a long-standing empirical-SE researcher. Single author. |
| 2 | Evidence Quality | 5/10 | 8,505 items but analysed as ~14 quarters x 5 teams; year level n=4; no quality data; one firm. |
| 3 | Currency | 3/10 | Published 2018, data is 2010-2013 (Kanban just adopted); WIP mechanics are durable, context is old. |
| 4 | Intent | 9/10 | Academic inquiry; data came from a collaborating company, no product being sold. |
| 5 | Bias & Objectivity | 8/10 | Reports mixed and contrary results; does not adjust significance and says why. |
| 6 | Logic & Coherence | 7/10 | Sound correlation reporting; but WIP/productivity coupling is not addressed (see Key Findings). |
| 7 | Corroboration | 4/10 | Author found no other quantitative real-case WIP study; only simulations and theory (Little's law). |
| 8 | Intellectual Honesty | 9/10 | Long threats-to-validity discussion; "advice to practitioners ... would thus not be conclusive". |
| 9 | Specificity | 8/10 | Spearman rho and p reported per team and overall; operational definitions given. |
| 10 | Relevance | 6/10 | Team Kanban (3.6 WIP per person); no solo setting. Transfers as a measurement design, not as a limit. |

**Score band:** borderline
(Intermediate weighted average ~6.7; was keep ~7.1 on the abstract. Downgrade drivers on full-text read: the
lead-time result is weaker than the abstract implies, and Currency and Relevance were rescored.) Included as the
SOLE quantitative real-case WIP study found, so it is kept for that documented reason, with the caveats below.

## Bias Guard Check

- [ ] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [x] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [ ] Neutral / no strong reaction

(I expected WIP limits to be supported, so the mixed result was scored generously on 5, 6 and 8.)

## Key Findings

- Data: 8,505 work items from five teams in one Scandinavian software firm, second half of 2010 to end of 2013 (3.5
  years, 14 quarters), pulled from Team Foundation Server. WIP is average items in progress per team member per
  quarter (mean 3.6); lead time is days from "Next" to "Ready for release"; productivity is churn-adjusted items per
  member per quarter (17.7 to 22.1). Quality was not measured and was assumed constant.
- The lead-time result is much weaker than the abstract suggests. The high WIP-lead time correlation (rho = 0.80) is
  at the year level (n = 4) and the author says it "should not be considered statistically significant"; at quarter
  level it "disappears" (rho = 0.12, p = 0.69). Per team it is significant in only one of five (Team A, rho = 0.78).
- WIP correlates positively with productivity at quarter level (rho = 0.71, p < 0.01; Teams D and E significant),
  while lead time and productivity are uncorrelated (rho = -0.08). The paper reads this as contradicting the claim
  that low WIP raises productivity. Significance was not adjusted for 18 tests (author's stated choice).
- Reviewer inference, not the author's: the paper's own identity is WIP = Productivity x Lead time (Little's law, p.
  1-2). With lead time flat, higher throughput per member forces higher WIP, so the WIP-productivity correlation is
  partly arithmetic and cannot show that high WIP causes productivity. Treat it as "no support for a productivity
  benefit of low WIP", not as "high WIP is good".
- Author's practical advice is explicitly conditional: low WIP if short lead time matters, higher WIP if throughput
  matters; no optimal limit was found. No individual or personal-Kanban data exist in this study.

## Verified Quote(s)

**Location reference:** Paper page numbers as printed (ESEM 18, pp. 1-8). Quotes 1 and 2: page 4, Section 3.1 "Lead
Time", first and second paragraphs. Quote 3: page 7, Section 5 "Conclusions", first paragraph, second sentence. Quote 4:
page 6, Section 4.1, final paragraph, last two sentences.

> While there is a high correlation between WIP and lead time (Spearman's ρ = 0.80), the correlation should not be considered statistically significant due to the small sample size.

> When increasing the granularity of time period from year to quarter, the relationship between WIP and lead time disappears; see Fig. 3 and Table 1 (ρ = 0.12, p = 0.69).

> However, a low WIP also seemed to reduce productivity, which is, of course, negative and in contrast to claims in the literature and among leading practitioners.

> If a short lead time is a priority, a low WIP limit seems sensible. If productivity is more important, a relatively high WIP limit should be defined.

**Access status:** cached/partial
**Access note:** full text read from a user-supplied copy on 2026-10-03; the live URL is bot-blocked. The supplied PDF
is image-only (a browser print-to-PDF with no text layer), so quotes were transcribed from the rendered pages and
cannot be located by text search in that file; the verifier should check them against the ACM page or any
text-bearing copy. The previous abstract-only version of this card was verified live on the SINTEF record.

## Inclusion Decision

**Decision:** Core
**Rationale:** Band is borderline; kept as the sole quantitative real-case WIP source (gap-fill), which makes it the
principal evidence that a specific WIP limit is not empirically established. Cite its limits (one firm, 2010-2013,
n = 4 at year level, no quality measure) every time it is used.

**Redundancy check:** t5-kanban-wip-empirical-study is the SAME paper and is excluded as a duplicate; this card
supersedes it. The Kanban Guide and 55 Degrees cards give theory (Little's law) only.

**Perspective category:** Academic
