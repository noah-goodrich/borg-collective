---
id: obs-20260611-workspaces-mount-pattern
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- devcontainer
- docker
- workspace-isolation
- volume-mount
category: domain_knowledge
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 20:39:25.149197+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-workspaces-mount-pattern

## content

Mounting devcontainer workspaces at /workspaces/<project> (rather than /workspace or a flat path) provides session-directory isolation when multiple projects share a Docker host or when borg's session-dir logic keys on the workspace path. The pattern requires coordinated changes across: Dockerfile WORKDIR, devcontainer.json workspaceFolder, devcontainer.json postStartCommand (symlink if needed), and docker-compose.yml volume + working_dir.

## resolution

Document the /workspaces/<project> mount pattern in docker-compose.base.yml comments and apply consistently across all projects using devcontainers.
