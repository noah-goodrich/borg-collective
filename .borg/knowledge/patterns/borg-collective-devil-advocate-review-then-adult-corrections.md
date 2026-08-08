---
id: borg-collective-devil-advocate-review-then-adult-corrections
project: borg-collective
domain: planning
tags:
- borg-collective
- borg-plan
- design-review
- workflow
- quality-gate
preconditions: []
steps:
- Produce initial design doc (e.g., in ~/.claude/plans/)
- Run /borg-plan on the design doc to structure it
- Run /borg-collective-review in Devil's Advocate / specialist mode
- Review objections; apply only those that address real structural gaps (cut scope,
  add missing acceptance criteria, fix naming)
- Write final PROJECT_PLAN.md with validated objective and acceptance criteria
- Archive any stale PROJECT_PLAN.md to docs/plans/assimilated/ with date prefix before
  overwriting
pitfalls:
- Accepting all Devil's Advocate objections uncritically inflates scope; filter through
  'The Adult' to keep only substantive corrections.
- Forgetting to archive the previous PROJECT_PLAN.md before overwriting it loses the
  historical record of prior shipped work.
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.392960+00:00'
updated_at: '2026-06-11 22:41:19.392960+00:00'
---

# borg-collective-devil-advocate-review-then-adult-corrections

## description

After running /borg-plan to produce a design doc, run /borg-collective-review in Devil's Advocate specialist mode to surface objections, then apply 'The Adult' filter to accept only high-signal corrections before writing PROJECT_PLAN.md.
