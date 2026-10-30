# A statistical approach to model evaluations

- Citation: Anthropic (Evan Miller; page credits the Anthropic team), "A statistical approach to model evaluations", Anthropic Research, 2024-11-19. Companion paper: E. Miller, "Adding Error Bars to Evals", arXiv:2411.00640.
- URL: https://www.anthropic.com/research/statistical-approach-to-model-evals
- Date accessed: 2026-10-30
- Evidence level: vendor documentation (research post backed by an arXiv preprint). Older than 2025; flagged.
- Access status: live

## Verified Quote(s)

Recommendation #1:

> we encourage researchers to report the SEM, derived from the Central Limit Theorem, alongside each calculated eval score

Recommendation #2:

> we recommend clustering standard errors on the unit of randomization

Recommendation #3:

> we recommend resampling answers from the same model several times

Recommendation #4:

> conducting a paired-differences test lets us eliminate the variance in question difficulty

## Key finding

Anthropic recommends reporting standard errors with every eval score, clustering errors on the unit of randomization (the case, when a case is run several times), resampling each question several times to reduce within-question variance, and comparing two configurations with paired differences on the same cases. Its CLT basis is challenged at small n by the Bowyer et al. position paper (see t1-bowyer-clt-small-n.md).
