# Evaluation best practices (OpenAI)

- Citation: OpenAI, "Evaluation best practices", OpenAI API documentation (undated on page).
- URL: https://developers.openai.com/api/docs/guides/evaluation-best-practices (redirected from https://platform.openai.com/docs/guides/evaluation-best-practices)
- Date accessed: 2026-10-30
- Evidence level: vendor documentation
- Access status: live

## Verified Quote(s)

> Adopt eval-driven development: Evaluate early and often. Write scoped tests at every stage.

> Set up continuous evaluation (CE) to run evals on every change

> Use pairwise comparison or pass/fail for more reliability

> Position bias (response order), verbosity bias (preferring longer responses)

> Control for response lengths as LLMs bias towards longer responses in general

> Maintain agreement: Use human feedback to calibrate automated scoring.

> Vibe-based evals: Using "it seems like it's working" as an evaluation strategy

> Biased design: Creating eval datasets that don't faithfully reproduce production traffic patterns.

## Key finding

OpenAI recommends continuous evaluation on every change, pairwise or pass/fail judging over scales, explicit controls for position and length bias, and human feedback to calibrate automated scoring. It gives no general guidance on dataset size or runs per case.
