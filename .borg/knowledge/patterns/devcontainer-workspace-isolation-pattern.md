---
id: devcontainer-workspace-isolation-pattern
project: borg-collective
domain: infrastructure
tags:
- devcontainer
- claude-code
- workspace
- isolation
- docker
preconditions: []
steps:
- In devcontainer.json workspaceFolder, set /workspaces/<project_name>
- In docker-compose.yml, mount the project source to /workspaces/<project_name>
- 'In postStartCommand (or Dockerfile), create symlink: ln -sfn /workspaces/<project_name>
  /workspace'
- In drone.zsh cmd_scaffold, set default workspace to /workspaces/<project_name> using
  the project name variable
- Add __WS_SYMLINK__ placeholder to any devcontainer templates for parameterized generation
pitfalls:
- Claude derives its ~/.claude/projects/ storage path directly from cwd; there is
  no config override — the path must be correct at process start
- If /workspace already exists as a real directory (not symlink) in the container
  image, the ln -sfn will fail silently or create a nested symlink; ensure the target
  doesn't pre-exist
- The reveal and ingle containers needed surgical fixes to existing devcontainer files
  — check both devcontainer.json AND docker-compose.yml AND Dockerfile for hardcoded
  /workspace references
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.211457+00:00'
updated_at: '2026-06-16 10:27:02.211457+00:00'
---

# devcontainer-workspace-isolation-pattern

## description

Configure each devcontainer to mount its project at /workspaces/<project_name> and add a /workspace symlink for legacy compatibility, ensuring Claude stores session history in a project-scoped directory.
