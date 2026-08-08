---
id: devcontainer-ssh-agent-propagation
project: borg-collective
domain: infrastructure
tags:
- devcontainer
- ssh
- ssh-agent
- docker
- permissions
preconditions: []
steps:
- 'In Dockerfile/devcontainer-base: add ''RUN install -d -o dev -g dev -m 700 /home/dev/.ssh''
  to create the mount point with correct ownership before any bind-mounts.'
- 'In devcontainer.json mounts: bind ~/.ssh/config and ~/.ssh/known_hosts as :ro (not
  the full ~/.ssh directory).'
- 'In devcontainer.json postCreateCommand: remove any ''chmod 600 /home/dev/.ssh/*''
  calls — they will fail with ''Read-only file system''.'
- 'In devcontainer.json postStartCommand: add ''sudo chmod a+rw /run/host-services/ssh-auth.sock
  2>/dev/null || true''.'
- 'Verification: exec into container, check ''ls -la ~/.ssh/'' shows 700 dev:dev,
  run ''ssh -T git@github.com'' and confirm authentication.'
pitfalls:
- chmod on :ro bind-mounted files always fails silently or loudly — remove all such
  calls from postCreateCommand.
- The ssh-auth.sock path (/run/host-services/ssh-auth.sock) is macOS/Docker Desktop
  specific; Linux hosts may use a different path — the '|| true' guard is essential.
- Mounting the entire ~/.ssh directory instead of individual files can expose the
  private key as readable inside the container.
- This fix must be applied to every devcontainer.json independently — there is no
  inheritance mechanism across projects.
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.274645+00:00'
updated_at: '2026-06-11 22:41:19.274646+00:00'
---

# devcontainer-ssh-agent-propagation

## description

Pattern for propagating SSH agent access correctly across devcontainer definitions after switching to read-only SSH config mounts.
