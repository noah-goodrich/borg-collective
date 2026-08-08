---
id: multi-concern-session-routing
project: borg-collective
domain: infrastructure
tags:
- git-workflow
- branching
- handoff
- borg-state
preconditions: []
steps:
- Enumerate all uncommitted changes and assign each to a category (e.g., borg-state,
  research-output, project-config, feature-implementation).
- Identify which category is the immediate PR target and stash or set aside everything
  else with a named reference.
- Cut the immediate PR branch from main, committing only the scoped category.
- Write a handoff doc for each deferred category describing what it contains, where
  to find it (stash ref or worktree path), and the exact commands to route it.
- Reference the handoff docs in the checkpoint's 'Next Session' section so the next
  session has a single entry point.
pitfalls:
- Forgetting to name the stash — anonymous stashes are hard to recover across sessions
  if other stashes accumulate.
- Letting research-branch config changes linger on the research branch permanently,
  causing merge conflicts when the branch is eventually closed.
- Treating PROJECT_PLAN.md edits as part of the borg-state PR when they represent
  a separate human-decision gate.
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.446248+00:00'
updated_at: '2026-06-11 22:41:19.446249+00:00'
---

# multi-concern-session-routing

## description

When a session produces changes across multiple independent concerns (research outputs, config, borg-state bookkeeping, hooks/tests), explicitly categorize each uncommitted artifact and route each to its own branch rather than committing everything together.
