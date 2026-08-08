---
id: 20260418-ssh-selective-mount
date: '2026-06-16'
project: borg-collective
domain: infrastructure
tags:
- docker
- devcontainer
- ssh
- security
- bind-mount
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260616-0347-orchestrator
created_at: '2026-06-16 10:27:02.162040+00:00'
updated_at: '2026-06-16 10:27:02.162042+00:00'
---

# 20260418-ssh-selective-mount

## decision

Mount only ~/.ssh/config:ro and ~/.ssh/known_hosts:ro into devcontainers instead of the full ~/.ssh directory

## context

Docker Desktop's grpcfuse was stamping mode 600 onto ~/.ssh/agent/ via com.docker.grpcfuse.ownership xattr, corrupting ssh-agent's socket directory permissions on every container start

## reasoning

Full ~/.ssh bind-mount exposes all keys and gives grpcfuse ownership semantics over the entire directory tree including the agent socket dir. Selective ro mounts for only the two files devcontainers actually need (config + known_hosts) eliminates the attack surface and prevents grpcfuse from touching ~/.ssh/agent at all.
