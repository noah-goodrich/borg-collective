---
id: 20260527-deferred-untracked-files-handoff
date: '2026-06-16'
project: borg-collective
domain: infrastructure
tags:
- git
- branching
- worktree
- deferred-work
- handoff
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260616-0347-orchestrator
created_at: '2026-06-16 10:27:02.407974+00:00'
updated_at: '2026-06-16 10:27:02.407975+00:00'
---

# 20260527-deferred-untracked-files-handoff

## decision

Deliberately leave untracked research/tooling files deferred rather than force-committing them to the borg-state branch

## context

Six untracked files (.claude/, docs/research/, hooks/, templates/, tests/) existed in the worktree but belonged to a different logical concern than the borg-state PR.

## reasoning

Mixing concerns into a single PR obscures intent and makes review harder. A separate chore/project-state branch keeps the borg-state PR clean and mergeable immediately.
