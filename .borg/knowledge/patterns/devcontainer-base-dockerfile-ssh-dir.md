---
id: devcontainer-base-dockerfile-ssh-dir
project: borg-collective
domain: infrastructure
tags:
- docker
- devcontainer
- dockerfile
- ssh
- permissions
preconditions: []
steps:
- 'In Dockerfile.base, add: RUN mkdir -p /home/dev/.ssh && chmod 700 /home/dev/.ssh
  && chown dev:dev /home/dev/.ssh'
- 'In docker-compose.yml, replace ~/.ssh volume mount with two selective mounts:'
- '  - ${HOME}/.ssh/config:/home/dev/.ssh/config:ro'
- '  - ${HOME}/.ssh/known_hosts:/home/dev/.ssh/known_hosts:ro'
- Do NOT mount ~/.ssh/agent or any socket files into containers
pitfalls:
- If the directory is not pre-created in the image, Docker will create it as root:root
  when mounting, causing permission errors for the dev user
- known_hosts may not exist on fresh machines — consider making that mount conditional
  or using an entrypoint that creates it if missing
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.171864+00:00'
updated_at: '2026-06-16 10:27:02.171865+00:00'
---

# devcontainer-base-dockerfile-ssh-dir

## description

Pre-create the /home/dev/.ssh directory in base Dockerfile so mounted ssh files land with correct ownership
