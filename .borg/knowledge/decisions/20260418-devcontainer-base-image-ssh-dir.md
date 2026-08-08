---
id: 20260418-devcontainer-base-image-ssh-dir
date: '2026-06-11'
project: borg-collective
domain: infrastructure
tags:
- devcontainer
- docker
- ssh
- image
- permissions
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 20:39:25.060589+00:00'
updated_at: '2026-06-11 20:39:25.060590+00:00'
---

# 20260418-devcontainer-base-image-ssh-dir

## decision

Add 'install -d -o dev -g dev -m 700 /home/dev/.ssh' as a layer in the devcontainer-base image rather than creating the directory in postCreateCommand.

## context

~/.ssh directory needs correct ownership and permissions (700, owned by dev user) before bind-mounts are applied. If done in postCreateCommand, the mount may already have wrong ownership.

## reasoning

Image layer ensures the directory exists with correct perms before any bind-mount occurs. This is idempotent and doesn't depend on postCreateCommand ordering.
