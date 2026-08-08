---
id: obs-20260616-claude-history-path-from-cwd
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- claude-code
- session-history
- workspace
- devcontainer
- path-derivation
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.211859+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260616-claude-history-path-from-cwd

## content

Claude Code derives the project history storage directory (~/.claude/projects/<hash>/) directly from the process working directory at startup. All devcontainers that mount to /workspace (singular, not project-scoped) share a single history directory ~/.claude/projects/-workspace/, causing all drones' session histories to intermingle regardless of which project they belong to.

## resolution

Mount each project to /workspaces/<project_name> (plural, VS Code convention). Claude then stores history in ~/.claude/projects/-workspaces-<project_name>/, isolating each project. Add a /workspace symlink for backward compat.
