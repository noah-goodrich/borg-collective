---
id: 20260418-ssh-agent-socket-poststart-not-postcreate
date: '2026-06-11'
project: borg-collective
domain: infrastructure
tags:
- devcontainer
- ssh-agent
- docker
- permissions
- lifecycle
alternatives: []
applies_to: []
confidence: 0.9
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 20:39:25.060078+00:00'
updated_at: '2026-06-11 20:39:25.060078+00:00'
---

# 20260418-ssh-agent-socket-poststart-not-postcreate

## decision

Apply ssh-auth.sock permission fix (chmod a+rw) in postStartCommand rather than postCreateCommand.

## context

The SSH agent socket at /run/host-services/ssh-auth.sock is a runtime artifact — it doesn't exist until the container starts and Docker Desktop mounts it. postCreateCommand runs once at container creation when the socket may not yet be present.

## reasoning

postStartCommand runs every container start, ensuring the socket is always accessible. postCreateCommand runs only once at creation and the socket lifecycle doesn't align with it.
