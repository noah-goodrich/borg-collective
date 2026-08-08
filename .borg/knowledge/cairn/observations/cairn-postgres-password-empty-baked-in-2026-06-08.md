---
id: cairn-postgres-password-empty-baked-in-2026-06-08
session_date: '2026-06-10'
project: cairn
tool: claude-code
tags:
- postgres
- docker
- credentials
- outage
- gotcha
category: gotcha
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260610-1630-cairn
superseded_by: null
created_at: '2026-06-10 16:50:37.421122+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# cairn-postgres-password-empty-baked-in-2026-06-08

## content

docker compose interpolates ${POSTGRES_PASSWORD} with no default. If the variable is not exported at compose up time, it silently bakes an empty string into the container. db.get_database_url() raises on empty password, causing every search/write to 500 with db unreachable. This is the #1 cairn outage cause.

## resolution

Create gitignored .env (repo root) and .devcontainer/.env, each containing POSTGRES_PASSWORD=<value>. Docker compose auto-loads both. Drone's secrets.zsh is NOT sufficient — it doesn't export the variable at compose interpolation time.
