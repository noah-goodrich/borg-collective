---
id: obs-20260319-cairn-test-db-not-autocreated
session_date: '2026-03-19'
project: cairn
tool: cursor
tags:
- alembic
- postgresql
- testing
- setup
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1925-cairn
superseded_by: null
created_at: '2026-06-11 23:12:50.698699+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260319-cairn-test-db-not-autocreated

## content

tests/test_migration.py targets the cairn_test database, but neither the migration code nor the test setup creates it. If cairn_test does not exist when the test suite runs, tests fail immediately with a connection error rather than a helpful missing-database message.

## resolution

Manually create the database before running tests: psql -U dev -d postgres -c 'CREATE DATABASE cairn_test;'. This step should be documented in the project README or added to a dev setup script.
