---
id: 20260616-workspace-per-project-path
date: '2026-06-16'
project: borg-collective
domain: infrastructure
tags:
- devcontainer
- drone
- workspace
- collision
- claude-code
alternatives: []
applies_to: []
confidence: 0.9
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260616-0347-orchestrator
created_at: '2026-06-16 10:27:02.208965+00:00'
updated_at: '2026-06-16 10:27:02.208966+00:00'
---

# 20260616-workspace-per-project-path

## decision

Default drone workspace changed from /workspace to /workspaces/<project_name>, with a legacy /workspace symlink created in postStartCommand when they differ.

## context

Every drone was using /workspace as its working directory, causing Claude to write all drones' session history into one shared ~/.claude/projects/-workspace/ directory, intermixing project history across unrelated projects.

## reasoning

Claude derives its project history storage path from the working directory. Using a project-scoped path like /workspaces/reveal means Claude stores history in ~/.claude/projects/-workspaces-reveal/, isolating each drone's history. The legacy symlink preserves backward compatibility for any tooling that hardcodes /workspace.
