---
id: obs-20260611-postgres-empty-password-outage
session_date: '2026-06-11'
project: cairn
tool: cursor
tags:
- docker-compose
- postgres
- environment-variables
- secrets
- devcontainer
- outage
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1925-cairn
superseded_by: null
created_at: '2026-06-11 20:31:18.017449+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-postgres-empty-password-outage

## content

Docker compose interpolates `${POSTGRES_PASSWORD}` as an empty string when the variable is not exported in the calling shell, even if it is defined in secrets.zsh. This caused cairn-api and the devcontainer to connect to Postgres with an empty password, resulting in every search/write returning 500 with 'db: unreachable'. The bug is silent at startup — the container launches successfully but all DB operations fail at runtime.

## resolution

Create a gitignored `.env` at the repo root (and `.devcontainer/.env` for the devcontainer). Docker compose auto-loads these files, so the password resolves correctly regardless of the calling shell's environment. Verified by unsetting the env var from the shell and confirming compose still resolved the correct value.
