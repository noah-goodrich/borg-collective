---
id: belief-view-union-column-contract
project: cairn
domain: architecture
tags:
- sql
- views
- codex
- belief-store
- postgresql
preconditions: []
steps:
- Identify the column contract from an existing query (e.g., search_knowledge()) that
  already spans all atom types
- For each atom table, map its native columns to the contract; for missing columns,
  derive values (e.g., status from superseded_by IS NOT NULL)
- Write the VIEW as a 3-way UNION ALL with explicit column aliases so each branch
  matches the contract positionally and by name
- Add EXTRACT(EPOCH FROM (now() - updated_at)) AS age_seconds as a computed column
  — requires updated_at on all branches (add via migration if missing)
- Expose via raw SQL in service.py (not SQLAlchemy autoload) for migration-ordering
  safety
- Gate staleness_score and other computed scores to a later phase — keep Phase 1a
  VIEW minimal
pitfalls:
- If any branch of the UNION is missing a column that others have, the VIEW will fail
  or silently return NULLs — enumerate all contract columns explicitly in every SELECT
  branch
- updated_at must exist on ALL three tables before the VIEW migration runs; verify
  with a dependency-ordered migration chain
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: null
superseded_by: null
created_at: '2026-07-24 03:53:11.045928+00:00'
updated_at: '2026-07-24 03:55:23.997706+00:00'
---

# belief-view-union-column-contract

## description

Build a unified typed VIEW over heterogeneous atom tables (decisions, patterns, observations) by establishing a shared column contract and deriving missing fields rather than altering source tables.
