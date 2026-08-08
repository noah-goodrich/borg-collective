---
id: docker-grpcfuse-ssh-recovery
project: borg-collective
domain: infrastructure
tags:
- docker
- ssh-agent
- grpcfuse
- macos
- launchd
- recovery
preconditions: []
steps:
- 'Confirm root cause: check xattr -l ~/.ssh/agent for com.docker.grpcfuse.ownership
  attribute'
- 'Kill wedged processes: pkill -f ssh-agent; pkill -f ssh-add'
- 'Restore directory permissions: chmod 700 ~/.ssh/agent'
- 'Strip the grpcfuse xattr: xattr -d com.docker.grpcfuse.ownership ~/.ssh/agent'
- 'Reload the ssh key: ssh-add --apple-use-keychain ~/.ssh/id_ed25519'
- 'Verify: ssh -T git@github.com'
- 'For permanent fix: update all devcontainer docker-compose.yml files to use selective
  mounts (config:ro, known_hosts:ro) instead of full ~/.ssh bind'
- Add heal_ssh_agent_dir() to install.sh so future re-runs auto-correct permissions
pitfalls:
- SIP blocks `launchctl kickstart` so you cannot force-restart the LaunchAgent directly
  — must kill processes and let launchd respawn
- launchd throttles respawns after repeated EACCES exits (255), so even after fixing
  perms the agent may not restart immediately — kill+wait
- grpcfuse re-applies the xattr on next Docker Desktop restart/update, so the one-time
  fix will recur without the selective-mount change
- The xattr attribute name is com.docker.grpcfuse.ownership — not intuitive from standard
  xattr output; look for it explicitly
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.168468+00:00'
updated_at: '2026-06-16 10:27:02.168468+00:00'
---

# docker-grpcfuse-ssh-recovery

## description

Recover a dead ssh-agent on macOS after Docker Desktop's grpcfuse strips execute permissions from the agent socket directory
