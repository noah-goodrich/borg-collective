---
id: multi-persona-architectural-review
project: borg-collective
domain: architecture
tags:
- review
- architecture
- directive
- multi-persona
preconditions: []
steps:
- Draft the directive fully
- 'Review it from at least three perspectives: technical skeptic (what assumptions
  are wrong?), operator (what breaks in prod?), implementer (what''s actually hard
  to build?)'
- Save the review to `docs/plans/reviews/<date>-<slug>-review.md`
- Identify which concerns require a verification spike vs. can be addressed by amending
  the directive
- Amend or sever the directive based on findings before implementation
pitfalls:
- Skipping review on 'obvious' directives is where the most expensive rework originates
- Save the review even if findings are mostly positive — it documents why alternatives
  were rejected
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.349470+00:00'
updated_at: '2026-06-16 10:27:02.349470+00:00'
---

# multi-persona-architectural-review

## description

Before committing to a large architectural directive, conduct a structured multi-persona review (e.g., skeptic, operator, implementer) and save findings before any code is written.
