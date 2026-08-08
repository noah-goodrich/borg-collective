---
id: obs-20260527-untracked-files-deferred-not-lost
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- untracked-files
- branch-strategy
- deferred-work
- project-state
category: domain_knowledge
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.454575+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260527-untracked-files-deferred-not-lost

## content

Several untracked files (.claude/, docs/research/*, hooks/borg-plan-promote.sh, tests/plan_promote.bats) were deliberately left untracked at session end rather than committed. These belong on a separate branch (chore/project-state-2026-05-27) that doesn't exist yet, and committing them to the borg-state branch would mix concerns. Leaving them untracked is the correct holding pattern when the target branch hasn't been cut yet.

## resolution

Documented the exact commands to cut the branch and pop the related stash in docs/plans/handoff/2026-05-27-research-branch-split.md. Next session should follow that doc rather than improvising.
