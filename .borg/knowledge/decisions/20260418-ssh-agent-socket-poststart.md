---
id: 20260418-ssh-agent-socket-poststart
date: '2026-06-11'
project: borg-collective
domain: infrastructure
tags:
- devcontainer
- ssh-agent
- socket
- permissions
- postStartCommand
alternatives: []
applies_to: []
confidence: 0.9
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 22:41:19.274260+00:00'
updated_at: '2026-06-11 22:41:19.274260+00:00'
---

# 20260418-ssh-agent-socket-poststart

## decision

Add 'sudo chmod a+rw /run/host-services/ssh-auth.sock 2>/dev/null || true' to postStartCommand rather than postCreateCommand for SSH agent socket access.

## context

The agent socket is a runtime artifact — it doesn't exist at image-build time and may not exist at postCreate time (container creation vs. container start are distinct lifecycle events).

## reasoning

postStartCommand runs every time the container starts, which matches the lifecycle of the agent socket. The '|| true' guard handles environments where the socket path doesn't exist (e.g., Linux hosts using a different socket path) without failing the container start.
