---
id: obs-20260616-postgres-function-overload-drop
session_date: '2026-06-16'
project: cairn
tool: claude-code
tags:
- postgres
- alembic
- migration
- functions
- overloading
category: gotcha
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260616-0914-cairn
superseded_by: null
created_at: '2026-06-16 10:27:03.293856+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260616-postgres-function-overload-drop

## content

Postgres supports function overloading by argument signature. A plain DROP FUNCTION search_knowledge() fails with 'function does not exist' if the signature doesn't match, and DROP FUNCTION IF EXISTS search_knowledge() drops only one overload. When recreating functions in migrations, you must DROP FUNCTION with the full argument signature, or use DROP FUNCTION IF EXISTS ... CASCADE.

## resolution

In migration 002 (documents table), use DROP FUNCTION search_knowledge(...) with the explicit parameter types before CREATE. This is noted as CRITICAL in the next-session plan.
