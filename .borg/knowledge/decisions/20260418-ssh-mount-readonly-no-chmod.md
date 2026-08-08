---
id: 20260418-ssh-mount-readonly-no-chmod
date: '2026-06-11'
project: borg-collective
domain: infrastructure
tags:
- devcontainer
- ssh
- docker
- bind-mount
- permissions
alternatives: []
applies_to: []
confidence: 0.9
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 20:39:25.059599+00:00'
updated_at: '2026-06-11 20:39:25.059600+00:00'
---

# 20260418-ssh-mount-readonly-no-chmod

## decision

Mount ~/.ssh/config and ~/.ssh/known_hosts as :ro bind-mounts and remove chmod commands from postCreateCommand, instead of mounting rw and chmoding after the fact.

## context

postCreateCommand was running chmod 600 on borg-mounted :ro files, causing 'Read-only file system' errors. SSH auth was broken inside devcontainers.

## reasoning

Read-only mounts are correct security posture for host SSH config inside containers. chmod on :ro files always fails. The container needs read access, not write access, to SSH config files.
