---
id: obs-20260423-claude-code-history-path-encoding
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- claude-code
- session-history
- workspace
- path-encoding
- devcontainer
category: domain_knowledge
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 20:39:25.125683+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260423-claude-code-history-path-encoding

## content

Claude Code encodes the workspace path into its local project history directory using a path-derived slug: `/workspace` → `~/.claude/projects/-workspace/`. If multiple unrelated projects all mount to `/workspace`, they all share the same Claude Code history directory. This causes context bleed between projects.

## resolution

Use per-project workspace paths (e.g., `/workspaces/<project_name>`) so each project gets its own isolated Claude Code history at `~/.claude/projects/-workspaces-<project_name>/`.
