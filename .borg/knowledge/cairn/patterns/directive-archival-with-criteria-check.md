---
id: directive-archival-with-criteria-check
project: cairn
domain: process
tags:
- directives
- archival
- project-management
- assimilated
preconditions: []
steps:
- Review the directive's acceptance criteria one by one against the current codebase/state
- Mark each criterion [x] in the directive file
- Move the file from docs/plans/ (or equivalent) to docs/plans/assimilated/
- Remove or update PROJECT_PLAN.md to drop the reference to the now-archived plan
- Commit both the archived directive and the PROJECT_PLAN.md removal together
pitfalls:
- Don't archive a directive if any criterion is unverified — the assimilated/ directory
  implies fully satisfied
- Forgetting to remove PROJECT_PLAN.md references leaves stale pointers that confuse
  future sessions
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1925-cairn
superseded_by: null
created_at: '2026-06-11 23:12:50.733511+00:00'
updated_at: '2026-06-11 23:12:50.733511+00:00'
---

# directive-archival-with-criteria-check

## description

Pattern for closing out a directive: verify all acceptance criteria are met, mark them [x], move the file to assimilated/, and remove the live plan reference
