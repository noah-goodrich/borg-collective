---
id: 20260423-per-project-workspace-isolation
date: '2026-06-11'
project: borg-collective
domain: infrastructure
tags:
- drone
- scaffold
- claude-code
- devcontainer
- workspace
- session-history
alternatives: []
applies_to: []
confidence: 0.9
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 20:39:25.123398+00:00'
updated_at: '2026-06-11 20:39:25.123399+00:00'
---

# 20260423-per-project-workspace-isolation

## decision

Change `drone scaffold --workspace` default from hardcoded `/workspace` to `/workspaces/<project_name>`, with a legacy `/workspace` symlink created at container start via `postStartCommand`.

## context

All drones were sharing `/workspace` as their container working directory. Claude Code encodes the workspace path into its project history location (`~/.claude/projects/`), so every drone — regardless of project — was reading and writing to the same Claude history at `~/.claude/projects/-workspace/`.

## reasoning

Per-project paths (`/workspaces/myproject`) give each drone an isolated Claude Code session history. The legacy symlink (`/workspace → /workspaces/myproject`) preserves backward compatibility for any tooling that assumes `/workspace`.
