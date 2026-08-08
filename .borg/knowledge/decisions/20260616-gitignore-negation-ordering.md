---
id: 20260616-gitignore-negation-ordering
date: '2026-06-16'
project: borg-collective
domain: code-quality
tags:
- git
- gitignore
- negation
- checkpoints
alternatives: []
applies_to: []
confidence: 0.9
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260616-0347-orchestrator
created_at: '2026-06-16 10:27:02.219577+00:00'
updated_at: '2026-06-16 10:27:02.219578+00:00'
---

# 20260616-gitignore-negation-ordering

## decision

Remove the `.borg/` ignore line that preceded `!.borg/checkpoints/`, making the negation unreachable

## context

The .gitignore contained `.borg/` followed by `!.borg/checkpoints/`. Git processes .gitignore rules top-to-bottom; a parent directory ignore swallows all children, so the negation never fires.

## reasoning

Negation of a subdirectory only works if the parent directory itself is not ignored. The fix is to either not ignore the parent or to restructure the rules so the negation is reachable.
