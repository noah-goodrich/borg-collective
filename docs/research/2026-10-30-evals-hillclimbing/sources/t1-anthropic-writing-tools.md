# Writing effective tools for agents — with agents

- Citation: Ken Aizawa et al., "Writing effective tools for agents — with agents", Anthropic Engineering blog, 2025-09-11.
- URL: https://www.anthropic.com/engineering/writing-tools-for-agents
- Date accessed: 2026-10-30
- Evidence level: vendor documentation (practitioner engineering post)
- Access status: live

## Verified Quote(s)

> We relied on held-out test sets to ensure we did not overfit to our “training” evaluations.

> Avoid overly strict verifiers that reject correct responses due to spurious differences

> the total number of tool calls, the total token consumption, and tool errors.

> Review the raw transcripts (including tool calls and tool responses) to catch any behavior

## Key finding

When Anthropic used Claude to optimize tool descriptions against evals (the same shape as skill-description hillclimbing), it relied on held-out test sets to detect overfitting and tracked tool calls, tokens and errors alongside accuracy. It warns that over-strict deterministic verifiers produce false failures, the deterministic-grader analogue of judge bias.
