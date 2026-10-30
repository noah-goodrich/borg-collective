# skill-creator SKILL.md (description optimization)

- Citation: Anthropic, "skill-creator" skill, SKILL.md, anthropics/skills GitHub repository, main branch (undated; read 2026-10-30).
- URL: https://github.com/anthropics/skills/blob/main/skills/skill-creator/SKILL.md
- Date accessed: 2026-10-30
- Evidence level: vendor documentation
- Access status: live

## Verified Quote(s)

Eval set composition:

> Create 20 eval queries — a mix of should-trigger and should-not-trigger. Save as JSON:

> Throw in some uncommon use cases and cases where this skill competes with another but should win.

Negatives:

> the most valuable ones are the near-misses

> The key thing to avoid: don't make should-not-trigger queries obviously irrelevant.

Easy cases:

> Complex, multi-step, or specialized queries reliably trigger skills when the description matches.

Optimization loop:

> It splits the eval set into 60% train and 40% held-out test

> running each query 3 times to get a reliable trigger rate

> It re-evaluates each new description on both train and test, iterating up to 5 times.

> — selected by test score rather than train score to avoid overfitting.

Model matching:

> so the triggering test matches what the user actually experiences.

Benchmark analysis:

> assertions that always pass regardless of skill (non-discriminating)

> high-variance evals (possibly flaky)

## Key finding

Anthropic's reference trigger eval is 20 queries split roughly evenly between should-trigger and should-not-trigger, with near-miss negatives (adjacent intent, competing skills) prized over obviously irrelevant ones, run 3 times each on the session's own model. Description optimization uses a 60/40 train/held-out split, up to 5 iterations, and picks the winner by held-out score; its benchmark analyst flags non-discriminating assertions and high-variance (flaky) evals.

## Notes

- With 8 held-out queries x 3 runs, a winner chosen by held-out score is itself a selection over up to 5 candidates, so the held-out score is optimistically biased; the SKILL.md does not address this.
