---
id: obs-20260616-postgres-function-overload-gotcha
session_date: '2026-06-16'
project: cairn
tool: claude-code
tags:
- postgres
- alembic
- migration
- function-overloading
- search_knowledge
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260616-0914-cairn
superseded_by: null
created_at: '2026-06-16 10:27:03.269273+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260616-postgres-function-overload-gotcha

## content

When adding parameters to a Postgres function in an Alembic migration, CREATE OR REPLACE only replaces the exact matching overload. The old signature survives as a ghost overload. Callers may silently resolve to the wrong version depending on how arguments are passed.

## resolution

Always DROP FUNCTION with the full old arg-list signature before CREATE in the migration body, and mirror the reverse DROP in the downgrade step.
