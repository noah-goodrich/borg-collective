---
id: borg-devil-advocate-review-then-adult-corrections
project: borg-collective
domain: planning
tags:
- borg-plan
- borg-collective-review
- design-validation
- workflow
preconditions: []
steps:
- Write initial design doc (e.g., in `~/.claude/plans/`)
- Run `/borg-plan` against the design doc to generate structured plan
- Run `/borg-collective-review` with Devil's Advocate / specialist persona to surface
  weaknesses
- 'Apply a filtered set of corrections (The Adult''s judgment: cut noise, keep substance)'
- Write `PROJECT_PLAN.md` with validated objective and explicit acceptance criteria
- Archive any stale prior `PROJECT_PLAN.md` to `docs/plans/assimilated/`
pitfalls:
- Devil's Advocate review may surface valid but scope-creeping concerns — apply judgment
  to filter to only corrections that improve correctness, not just coverage.
- Acceptance criteria must include a regression criterion (what breaks if this fails)
  — easy to omit.
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.300114+00:00'
updated_at: '2026-06-16 10:27:02.300115+00:00'
---

# borg-devil-advocate-review-then-adult-corrections

## description

Design validation workflow: run `/borg-plan` on a design doc, then run `/borg-collective-review` in Devil's Advocate mode as a specialist, apply 'The Adult' corrections to the output, then write the validated `PROJECT_PLAN.md`.
