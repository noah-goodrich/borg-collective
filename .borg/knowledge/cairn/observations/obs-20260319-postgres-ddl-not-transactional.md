---
id: obs-20260319-postgres-ddl-not-transactional
session_date: '2026-03-19'
project: cairn
tool: cursor
tags:
- postgres
- ddl
- transactions
- testing
- alembic
category: domain_knowledge
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260611-1925-cairn
superseded_by: null
created_at: '2026-06-11 20:31:17.988384+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260319-postgres-ddl-not-transactional

## content

PostgreSQL DDL statements (CREATE TABLE, CREATE INDEX, CREATE EXTENSION, etc.) cannot be rolled back inside a transaction. This means test isolation via transaction rollback is not viable for migration integration tests — you must use a dedicated database and explicit downgrade calls.

## resolution

Use a dedicated test database (cairn_test) and always bracket migration tests with 'alembic downgrade base' before and after, not transaction rollback.
