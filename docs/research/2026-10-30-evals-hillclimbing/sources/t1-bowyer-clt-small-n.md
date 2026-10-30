# Position: Don't Use the CLT in LLM Evals With Fewer Than a Few Hundred Datapoints

- Citation: Sam Bowyer, Laurence Aitchison, Desi R. Ivanova, "Position: Don't Use the CLT in LLM Evals With Fewer Than a Few Hundred Datapoints", ICML 2025 (spotlight position paper), arXiv:2503.01747 (v3, 2025-05-28).
- URL: https://arxiv.org/abs/2503.01747 (HTML body: https://arxiv.org/html/2503.01747)
- Date accessed: 2026-10-30
- Evidence level: peer-reviewed (ICML 2025 position track)
- Access status: live (abstract page and HTML body; HTML body read for first ~100k characters only)

## Verified Quote(s)

Abstract:

> In these small-data settings, we demonstrate that CLT-based methods perform very poorly, usually dramatically underestimating uncertainty

> (i.e. producing error bars that are too small).

> We give recommendations for alternative frequentist and Bayesian methods that are both easy to implement

Body (interval recommendations):

> We would, therefore, recommend using WS or Bayesian intervals in practice.

> WS demonstrates favourable coverage and length properties and is generally preferred to the exact CP

> With small data, we recommend Bayesian intervals for the difference or odds ratio.

> We would recommend using the paired Bayes method as it can account for correlations and thus produce narrower intervals.

## Key finding

At the scale of hand-written agent eval sets (tens of cases), CLT/normal-approximation error bars are too narrow; Wilson score or Bayesian Beta intervals should be used for a single pass rate. For comparing two configurations on the same cases, a paired Bayesian method is recommended because it exploits correlation and gives narrower honest intervals.

## Notes

- Contrarian relative to t1-anthropic-statistical-evals.md, which recommends CLT-based SEM.
- "WS" = Wilson score; "CP" = Clopper-Pearson.
