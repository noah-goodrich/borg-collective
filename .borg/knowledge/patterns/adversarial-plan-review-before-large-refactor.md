---
id: adversarial-plan-review-before-large-refactor
project: borg-collective
domain: architecture
tags:
- planning
- review
- adversarial
- multi-agent
preconditions: []
steps:
- Draft the initial plan
- Assign fact-checker personas to challenge each premise independently
- Assign Collective/domain-expert personas to evaluate feasibility
- Synthesize findings — look specifically for premises where all reviewers agree the
  stated direction is backwards
- Delete or invert any plan sections built on falsified premises before execution
  begins
- Capture corrections in persistent memory / project source-of-truth documents
pitfalls:
- A plan that survives surface-level review can still be built on an inverted premise
  that only becomes obvious when you ask 'what actually loads this at runtime?'
- Time pressure encourages skipping adversarial review on 'obvious' refactors — these
  are exactly the ones most likely to have hidden inversions
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.541760+00:00'
updated_at: '2026-06-16 10:27:02.541761+00:00'
---

# adversarial-plan-review-before-large-refactor

## description

Before executing a large architectural refactor, run a multi-persona adversarial review of the plan to surface inverted premises or false assumptions.
