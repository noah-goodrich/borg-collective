---
id: obs-20260418-ssh-auth-sock-not-present-at-postcreate
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- devcontainer
- ssh-agent
- docker-desktop
- lifecycle
- permissions
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 20:39:25.062397+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260418-ssh-auth-sock-not-present-at-postcreate

## content

The Docker Desktop SSH agent socket (/run/host-services/ssh-auth.sock) is not guaranteed to exist when postCreateCommand runs. It is a runtime mount that appears when the container starts. Attempting to chmod it in postCreateCommand will fail silently or with 'No such file or directory'.

## resolution

Move ssh-auth.sock permission fix to postStartCommand with '2>/dev/null || true' to handle cases where the socket doesn't exist (e.g. non-Mac hosts or SSH agent not running).
