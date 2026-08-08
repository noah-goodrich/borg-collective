---
id: borg-directive-to-plan-lifecycle
project: borg-collective
domain: project-management
tags:
- borg
- lifecycle
- shell
- workflow
preconditions: []
steps:
- Author directive markdown in docs/plans/directives/<slug>.md
- Run `borg start <slug>` — moves file to PROJECT_PLAN.md; fails if PROJECT_PLAN.md
  already exists (one in-flight constraint)
- Work the plan; update PROJECT_PLAN.md directly
- Run `borg assimilate` when done — moves PROJECT_PLAN.md to docs/plans/assimilated/<slug>.md
  with completion metadata
pitfalls:
- If the directive was written mid-session and never staged, git mv will fail — cmd_start
  handles this via git ls-files check, but manual invocations of git mv will not.
- PROJECT_PLAN.md presence is the mutex; deleting it manually without assimilating
  silently unlocks a second promotion.
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.285542+00:00'
updated_at: '2026-06-11 22:41:19.285542+00:00'
---

# borg-directive-to-plan-lifecycle

## description

Three-state filesystem lifecycle for work items: directives/ (backlog) → PROJECT_PLAN.md (in-flight, one at a time) → assimilated/ (done). Transitions are enforced by borg start and borg assimilate.
