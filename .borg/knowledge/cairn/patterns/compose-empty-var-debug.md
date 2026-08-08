---
id: compose-empty-var-debug
project: cairn
domain: infrastructure
tags:
- docker-compose
- debugging
- environment
- postgres
preconditions: []
steps:
- 'Observe service 500 errors with a message like ''db: unreachable'' — these can
  mask a credential problem'
- Check compose.yml for bare ${VAR} interpolations with no default (no :-fallback)
- 'Verify whether the variable is actually set in the current shell context: `echo
  $VAR` or `docker compose config | grep VAR`'
- Identify all contexts that need the variable (local shell, devcontainer, CI) and
  trace which sourcing mechanism each uses
- Create a gitignored .env file in the compose project root with VAR=value; docker
  compose auto-loads it
- Create a parallel .devcontainer/.env for devcontainer contexts if needed
- Recreate affected containers (`docker compose up --force-recreate <service>`) to
  pick up the new env
- Verify with health/stats endpoints and an end-to-end write+read round-trip
pitfalls:
- Docker Compose substitutes a missing variable as an empty string with no warning
  — the resulting config looks valid but auth fails silently
- Drone/CI may source a different secrets file than local dev; confirm both paths
  independently
- Restarting (not recreating) a container does not re-read compose.yml env — must
  recreate
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1925-cairn
superseded_by: null
created_at: '2026-06-11 23:12:50.725039+00:00'
updated_at: '2026-06-11 23:12:50.725039+00:00'
---

# compose-empty-var-debug

## description

Diagnose and fix a silent empty-variable substitution in docker-compose that causes service authentication failures
