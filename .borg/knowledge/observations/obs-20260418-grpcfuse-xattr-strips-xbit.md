---
id: obs-20260418-grpcfuse-xattr-strips-xbit
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- docker
- grpcfuse
- ssh-agent
- macos
- xattr
- permissions
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.173716+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260418-grpcfuse-xattr-strips-xbit

## content

Docker Desktop's grpcfuse filesystem layer writes a com.docker.grpcfuse.ownership xattr onto host directories that are bind-mounted into containers. On macOS, this xattr causes Docker to reset the directory mode to 600 (stripping the execute bit) on container lifecycle events. ssh-agent's agent_cleanup_stale() requires execute permission on ~/.ssh/agent/ to enumerate socket files — with mode 600 it fails with EACCES and exits 255. launchd then throttles respawns, leaving the host ssh-agent permanently dead until manually recovered.

## resolution

Remove the xattr with `xattr -d com.docker.grpcfuse.ownership ~/.ssh/agent`, restore with `chmod 700 ~/.ssh/agent`. Permanently prevent by switching all devcontainer compose files from full ~/.ssh bind-mount to selective config:ro + known_hosts:ro mounts, which never touch the agent directory.
