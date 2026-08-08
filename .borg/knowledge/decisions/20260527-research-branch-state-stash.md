---
id: 20260527-research-branch-state-stash
date: '2026-06-11'
project: borg-collective
domain: infrastructure
tags:
- git-workflow
- branching
- stash
- research-branch
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 22:41:19.445486+00:00'
updated_at: '2026-06-11 22:41:19.445487+00:00'
---

# 20260527-research-branch-state-stash

## decision

Project-wide config files modified on a research branch are stashed temporarily under a named reference so the borg-state PR can be cut from main, with explicit instructions to pop and re-route to a dedicated `chore/project-state-*` branch.

## context

Five files (.gitignore, CLAUDE.md, README.md, borg.zsh, docs/architecture.md) were modified while working on `research/agent-teams-2026-05-23` — a branch that shouldn't carry project-wide concerns permanently.

## reasoning

Stashing preserves the changes without losing them while allowing a clean branch cut. Named stash reference (`borg-state-2026-05-27-temp-stash`) makes it recoverable across sessions without relying on memory.
