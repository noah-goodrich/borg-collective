# AI Evals: Everything You Need to Know (Evals FAQ)

- Citation: Hamel Husain and Shreya Shankar, "AI Evals: Everything You Need to Know" (Evals FAQ), hamel.dev, published 2026-09-18 (modified 2026-09-21 per page).
- URL: https://hamel.dev/blog/posts/evals-faq/
- Date accessed: 2026-10-30
- Evidence level: practitioner
- Access status: live (page is ~154k characters; read in two fetches)

## Verified Quote(s)

Binary vs Likert:

> Binary evaluations force clearer thinking and more consistent labeling.

Code vs judge:

> Use a code-based eval when a deterministic rule can identify the failure.

Q "How do I know if I can trust my automated eval?":

> True positive rate (TPR), also called recall, measures how many actual failures the evaluator catches.

> True negative rate (TNR) measures how many good outputs the evaluator correctly passes.

Q "How many examples do I need for an eval?":

> Plan to label 100 to 200 examples for each failure mode.

> Split these examples into train, dev, and test sets.

> When possible, include 30 to 50 Pass examples and 30 to 50 Fail examples in both the dev and test sets.

One judge per failure mode:

> we recommend building a separate judge for each type of failure.

Q "How are evaluations used differently in CI/CD vs. monitoring production?":

> CI evals protect against known regressions before deployment.

> Test datasets for CI are small (in many cases 100+ examples) and purpose-built.

> Favor assertions or other deterministic checks over LLM-as-judge evaluators.

Q "How often should I run my evals?":

> The more expensive the eval, the greater benefit it needs to provide to justify running it frequently.

RAG section:

> Once you know your judge’s True Positive and True Negative rates, you can correct its estimates

## Key finding

Husain and Shankar recommend binary pass/fail judges, one per failure mode, validated against 100-200 human labels per failure mode split train/dev/test with balanced Pass and Fail examples, measured by TPR and TNR rather than raw agreement. CI should favour deterministic assertions over judges, and run frequency should scale inversely with eval cost.
