---
id: obs-20260418-ssh-agent-socket-lifecycle
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- devcontainer
- ssh-agent
- socket
- docker
- container-lifecycle
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.275693+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260418-ssh-agent-socket-lifecycle

## content

The SSH agent socket (/run/host-services/ssh-auth.sock on macOS/Docker Desktop) is a runtime artifact. It does not exist during postCreateCommand (image build / first-time container creation) and must be re-permissioned on every container start, not just creation.

## resolution

Move 'sudo chmod a+rw /run/host-services/ssh-auth.sock' to postStartCommand with '2>/dev/null || true' guard. This runs on every start and is safe to no-op when the socket is absent.
