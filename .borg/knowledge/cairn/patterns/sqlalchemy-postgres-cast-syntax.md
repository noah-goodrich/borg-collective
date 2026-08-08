---
id: sqlalchemy-postgres-cast-syntax
project: cairn
domain: database
tags:
- sqlalchemy
- postgres
- pgvector
- named-parameters
- casting
preconditions: []
steps:
- Identify any query using `:param::type` syntax (Postgres cast shorthand) in a SQLAlchemy
  text() expression
- Replace `:param::type` with `CAST(:param AS type)` — e.g., `CAST(:emb AS vector)`
- Verify the query runs without silent failure by checking that results are returned
  or rows are updated
pitfalls:
- The `:param::type` syntax looks valid and SQLAlchemy does not raise an exception
  — it silently misparses the `::` as part of the parameter name, causing the cast
  to never execute
- Affects all pgvector similarity search queries and embedding backfill UPDATE statements
  simultaneously — a single syntax choice breaks the entire embedding pipeline
- 'The failure is silent: no error is raised, searches return empty results, and UPDATEs
  appear to succeed but affect 0 rows'
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1925-cairn
superseded_by: null
created_at: '2026-06-11 20:31:17.997513+00:00'
updated_at: '2026-06-11 20:31:17.997514+00:00'
---

# sqlalchemy-postgres-cast-syntax

## description

Safe pattern for casting named parameters to custom Postgres types (e.g., vector) in SQLAlchemy text() queries
