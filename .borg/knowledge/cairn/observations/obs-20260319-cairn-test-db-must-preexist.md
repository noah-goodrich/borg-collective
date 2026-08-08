---
id: obs-20260319-cairn-test-db-must-preexist
session_date: '2026-03-19'
project: cairn
tool: cursor
tags:
- alembic
- postgres
- testing
- setup
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1925-cairn
superseded_by: null
created_at: '2026-06-11 20:31:17.986664+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260319-cairn-test-db-must-preexist

## content

The cairn_test database must be manually pre-created before running test_migration.py. Alembic's migration engine connects to an existing database; it does not CREATE DATABASE. If cairn_test is absent, the test suite fails immediately with a connection/database-not-found error, not a helpful migration error.

## resolution

Run: psql -U dev -d postgres -c 'CREATE DATABASE cairn_test;' before the first test run. Document this in the project README or a test prerequisites section.
