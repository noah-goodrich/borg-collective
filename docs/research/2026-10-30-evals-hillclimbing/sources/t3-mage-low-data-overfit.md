# MAGE: Understanding Stability-Performance Trade-offs in Multi-component Prompt Optimization

- Citation: Prateek Singh, "MAGE: Understanding Stability-Performance Trade-offs in Multi-component Prompt Optimization", arXiv:2607.11944, submitted 11 July 2026.
- URLs: https://arxiv.org/abs/2607.11944 and https://arxiv.org/html/2607.11944
- Date accessed: 2026-10-30
- Evidence level: peer-reviewed status unknown (arXiv preprint, single author)
- Access status: live

## Verified Quote(s)

Abstract (arxiv.org/abs):

> in low-data regimes (Ntrain=30), well-designed fixed prompts outperform all reflective optimizers,

> expanding the candidate pool from n=3 to n=5 improves mean accuracy by +21.6% while increasing variance by 3.7x

> should be evaluated in terms of both performance and stability, not just peak accuracy.

Section 5.2, "Why does Gepa overfit?" (HTML):

> Gepa's optimized prompts score 34.0% at test time while the unoptimized seed achieves 62.4%

> This is a structural risk of any failure-grounded optimizer with small training sets

Section 5.1, "Implementation" (HTML):

> The 34.0% test score reflects genuine overfitting to Ntrain=30, not implementation error.

Section 6.1, "When not to optimize." (HTML):

> In low-data regimes (Ntrain≤30), strong fixed prompts may outperform all reflective optimizers.

## Key finding

At 30 training examples (GSM8K-Hard, 5 seeds, 50 test), a GEPA re-implementation overfit badly: 34.0% on test against 62.4% for the unoptimized seed, and no reflective optimizer beat a well-written fixed prompt. This is direct evidence that prompt optimization at small n can make things worse, and the author recommends reporting stability (variance across seeds) alongside peak accuracy. Caveat: single-author preprint, and the GEPA result is a re-implementation, not the reference code.
