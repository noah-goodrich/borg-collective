# A statistical approach to model evaluations

- Citation: Anthropic, "A statistical approach to model evaluations", Anthropic Research, November 19, 2024.
- URL: https://www.anthropic.com/research/statistical-approach-to-model-evals
- Date accessed: 2026-10-30
- Evidence level: vendor documentation (Anthropic research post backed by a paper). OLDER SOURCE (2024), but the statistics do not age.
- Access status: live

## Verified Quote(s)

"Recommendation #2: Cluster standard errors":

> we recommend clustering standard errors on the unit of randomization

"Recommendation #4: Analyze paired differences":

> between 0.3 and 0.7 on a scale of −1 to +1

> “free” variance reduction technique

"Recommendation #5: Use power analysis":

> confidence intervals associated with any statistical tests will tend to be wide

> small differences will likely go undetected

## Key finding

Report eval scores with standard errors clustered on the case, compare variants with paired differences, and use power analysis to choose the number of cases before running. With few questions, only large differences can be detected. Repeated runs reduce within-case noise but do not add independent cases.
