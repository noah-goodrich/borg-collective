---
id: obs-20260611-ci-postgres-db-env-var
session_date: '2026-06-11'
project: cairn
tool: cursor
tags:
- ci
- postgres
- environment-variables
- github-actions
- test-failures
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1925-cairn
superseded_by: null
created_at: '2026-06-11 20:31:18.036277+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-ci-postgres-db-env-var

## content

CI was using POSTGRES_NAME as the environment variable to set the test database name, but the official postgres Docker service container expects POSTGRES_DB. The database was never created, causing all DB-dependent tests to fail. The error was not immediately obvious because the postgres container started successfully — it just didn't create the expected database.

## resolution

Rename the CI env var from POSTGRES_NAME to POSTGRES_DB to match the postgres image's documented environment variable.
