# Large Language Models as Optimizers (OPRO)

- Citation: Chengrun Yang, Xuezhi Wang, Yifeng Lu, Hanxiao Liu, Quoc V. Le, Denny Zhou, Xinyun Chen, "Large Language Models as Optimizers", arXiv:2309.03409 (v1 Sep 2023, v3 Apr 2024); ICLR 2024.
- URL: https://arxiv.org/html/2309.03409v3
- Date accessed: 2026-10-30
- Evidence level: peer-reviewed (ICLR 2024). OLDER SOURCE (2023-2024), predates current frontier models.
- Access status: live (first 100k of 171k characters read)

## Verified Quote(s)

Section 5.4, "Overfitting Analysis in Prompt Optimization":

> our training accuracies are often 5%-20% higher than our test accuracies

> Setting aside a larger training set and optimizing for fewer steps (early stopping) may help reduce overfitting.

Section 5.2.1 (GSM8K training subset):

> we randomly sample 3.5% examples from the GSM8K training set

## Key finding

Even with about 262 training examples (3.5% of GSM8K's 7,473), OPRO's optimized prompts scored 5 to 20 points higher on train than on test. The authors' remedy is a larger training set and fewer steps (early stopping).
