---
id: 20260527-borg-state-pr-isolation
date: '2026-06-11'
project: borg-collective
domain: infrastructure
tags:
- git-workflow
- branching
- borg-state
- checkpoints
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 22:41:19.445006+00:00'
updated_at: '2026-06-11 22:41:19.445007+00:00'
---

# 20260527-borg-state-pr-isolation

## decision

Borg-state checkpoint commits are scoped exclusively to .borg/ and docs/plans/ files; all other uncommitted worktree changes are deliberately excluded and routed to separate branches.

## context

A weekend session produced changes across multiple concerns (research outputs, project-wide config files, hooks/tests, borg-state files) all sitting in the same worktree. The question was how to commit them cleanly.

## reasoning

Mixing research outputs, project-state config changes, and borg-state bookkeeping in a single PR would obscure the diff and make rollback harder. Isolating borg-state into its own branch (`chore/borg-state-YYYY-MM-DD`) keeps the commit history legible and makes it safe to land on main without pulling in unreviewed work.
