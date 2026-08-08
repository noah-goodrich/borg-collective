---
id: borg-directive-lifecycle
project: borg-collective
domain: workflow
tags:
- borg
- lifecycle
- directive
- project-plan
- assimilate
preconditions: []
steps:
- Write directive to docs/plans/directives/<slug>.md (backlog state).
- Run 'borg start <slug>' — cmd_start checks git ls-files, uses git mv or plain mv
  to promote file to PROJECT_PLAN.md. Fails fast if PROJECT_PLAN.md already exists
  (one in-flight enforced).
- Do the work described in PROJECT_PLAN.md.
- Run 'borg assimilate' — moves PROJECT_PLAN.md to docs/plans/assimilated/<slug>.md
  (done state), updates registry, commits.
pitfalls:
- If the directive was written but not committed, git mv will fail — cmd_start must
  check git ls-files first and fall back to plain mv.
- A second borg start call while PROJECT_PLAN.md exists will be blocked by the file
  existence check — this is intentional but can surprise users who forgot they already
  promoted a directive.
- The slug used in borg start must exactly match the filename in directives/ (no fuzzy
  matching).
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 20:39:25.082724+00:00'
updated_at: '2026-06-11 20:39:25.082725+00:00'
---

# borg-directive-lifecycle

## description

Three-state filesystem lifecycle for borg work items: backlog → in-flight → done, enforced by directory location and a singleton file.
