---
id: obs-20260527-research-branch-project-state-contamination
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- git
- branching
- research-branch
- worktree-hygiene
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.398845+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260527-research-branch-project-state-contamination

## content

Project-wide files (.gitignore, CLAUDE.md, README.md, borg.zsh, docs/architecture.md) accumulated uncommitted changes on a research branch (research/agent-teams-2026-05-23). These are cross-cutting concerns that don't belong in research branch history — they'd be difficult to land on main without cherry-picking or creating a messy merge.

## resolution

Stash the modified files before cutting the borg-state PR; unstash onto a dedicated `chore/project-state-YYYY-MM-DD` branch and open a separate PR. Going forward, commit project-state changes to a chore branch immediately rather than letting them accumulate on whatever branch is currently active.
