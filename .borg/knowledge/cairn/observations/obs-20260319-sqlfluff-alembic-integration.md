---
id: obs-20260319-sqlfluff-alembic-integration
session_date: '2026-03-19'
project: cairn
tool: cursor
tags:
- sqlfluff
- alembic
- linting
- sql
- code-quality
category: pattern_discovered
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260611-1925-cairn
superseded_by: null
created_at: '2026-06-11 20:31:17.989094+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260319-sqlfluff-alembic-integration

## content

SQLFluff can lint SQL embedded in Alembic migration files (the raw SQL inside op.execute() calls) by targeting the alembic/ directory with --dialect postgres. This catches SQL style issues in migrations that Python linters (ruff) would ignore entirely.

## resolution

Add 'sqlfluff lint alembic/ --dialect postgres' to the project lint entrypoint alongside ruff. Configure .sqlfluff with [sqlfluff] dialect = postgres.
