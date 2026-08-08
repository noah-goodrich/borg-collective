---
id: cairn-fix-postgres-password-outage
project: cairn
domain: ops
tags:
- postgres
- docker
- ops
- credentials
- outage
preconditions: []
steps:
- 'Confirm the symptom: cairn health returns 500; cairn search returns 0 results with
  no error; db.get_database_url() raises on empty password.'
- Create .env at the cairn repo root with POSTGRES_PASSWORD=<actual_password> (gitignored).
- Create .devcontainer/.env with the same variable (gitignored). docker compose auto-loads
  both.
- 'Recreate the containers: drone restart cairn (or docker compose up --force-recreate).'
- 'Verify: cairn health returns ok; cairn record session + cairn search round-trip
  succeeds.'
pitfalls:
- drone sources secrets.zsh but NOT local.zsh — POSTGRES_PASSWORD exported only in
  local.zsh is invisible to the compose interpolation.
- The compose ${POSTGRES_PASSWORD} variable has no default; it silently interpolates
  to an empty string rather than erroring.
- The Python CLI (~/.local/bin/cairn) goes direct-Postgres and needs POSTGRES_PASSWORD
  in the environment. The shell shim (~/.config/dotfiles/zsh/bin/cairn) uses HTTP
  and does not need it — hooks work fine via the shim.
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260610-1630-cairn
superseded_by: null
created_at: '2026-06-10 16:50:37.418613+00:00'
updated_at: '2026-06-10 16:50:37.418614+00:00'
---

# cairn-fix-postgres-password-outage

## description

Recover from the #1 cairn outage: empty POSTGRES_PASSWORD baked into the container causes all DB calls to 500 with db unreachable.
