---
id: obs-20260611-ci-postgres-db-env-var-wrong
session_date: '2026-06-11'
project: cairn
tool: cursor
tags:
- ci
- github-actions
- postgres
- environment-variables
- test-failures
category: error_encountered
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1925-cairn
superseded_by: null
created_at: '2026-06-11 23:12:50.742422+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-ci-postgres-db-env-var-wrong

## content

CI was using POSTGRES_NAME as the environment variable for the database name, but the correct variable for the postgres service container in GitHub Actions is POSTGRES_DB. Because the database was never created, all DB-dependent tests failed in CI while passing locally.

## resolution

Rename the CI env var from POSTGRES_NAME to POSTGRES_DB in the workflow file.
