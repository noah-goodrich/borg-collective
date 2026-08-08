---
id: directive-lifecycle-assimilate-sever
project: borg-collective
domain: project-management
tags:
- directives
- backlog
- docs
- borg-collective
- workflow
preconditions: []
steps:
- Locate directive file in backlog or docs/plans/
- Verify all acceptance criteria are met (or explicitly note which are not applicable)
- 'If completed: move to docs/plans/assimilated/ with date-prefixed filename'
- 'If dropped/rejected: move to docs/plans/severed/ with date-prefixed filename'
- Commit the move with a clear message distinguishing assimilation from severance
- Confirm working tree is clean before tagging a release
pitfalls:
- Directive may have acceptance criteria that are already met from a prior session
  — check before doing duplicate work
- Forgetting to commit the directive move before tagging leaves the release in an
  ambiguous state
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.347536+00:00'
updated_at: '2026-06-11 22:41:19.347536+00:00'
---

# directive-lifecycle-assimilate-sever

## description

Lifecycle for closing out a planning directive: move completed ones to assimilated/, move rejected/dropped ones to severed/, then commit with semantic message
