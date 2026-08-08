---
id: obs-20260616-ci-postgres-db-wrong
session_date: '2026-06-16'
project: cairn
tool: claude-code
tags:
- cairn
- ci
- postgres
- github-actions
- configuration
category: error_encountered
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260616-0914-cairn
superseded_by: null
created_at: '2026-06-16 10:27:02.543865+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260616-ci-postgres-db-wrong

## content

cairn ci.yml had an incorrect POSTGRES_DB value, causing integration tests to fail in CI while passing locally (where the DB name matched the local config).

## resolution

Corrected POSTGRES_DB in ci.yml to match the value expected by the test suite. Included in cairn PR #6.
