---
id: obs-20260611-compose-empty-password-outage
session_date: '2026-06-11'
project: cairn
tool: cursor
tags:
- docker-compose
- postgres
- environment
- secrets
- devcontainer
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1925-cairn
superseded_by: null
created_at: '2026-06-11 23:12:50.726128+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-compose-empty-password-outage

## content

docker-compose silently interpolates ${POSTGRES_PASSWORD} as an empty string when the variable is not exported in the current shell. This produced a container that started successfully (health check passed at the process level) but every DB operation returned 500 with 'db: unreachable'. The devcontainer and cairn-api both baked the empty value at container-create time, so a mere restart did not fix it — a full recreate was required after the .env was in place.

## resolution

Created gitignored .env at repo root and .devcontainer/.env; docker compose auto-loads both. Recreated cairn-api with `docker compose up --force-recreate cairn-api`. End-to-end health + write/read verified clean.
