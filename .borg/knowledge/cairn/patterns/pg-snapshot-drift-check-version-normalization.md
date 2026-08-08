---
id: pg-snapshot-drift-check-version-normalization
project: cairn
domain: infrastructure
tags:
- postgres
- schema-drift
- ci
- pg16
- pg17
- snapshot-testing
preconditions: []
steps:
- Identify the header lines in pg_dump output that embed the server version (e.g.,
  '-- PostgreSQL database dump' comment block)
- Add a normalization step (sed, regex replace, or Python) that strips or replaces
  the version token before comparison
- Store the normalized snapshot in version control
- Run normalization on both the stored snapshot and the freshly generated dump before
  diffing
pitfalls:
- Forgetting to normalize means the drift check will always fail when CI runs pg16
  and local dev runs pg17 (or any version mismatch), masking real schema changes in
  noise
- Over-normalizing (stripping too many headers) can hide meaningful structural differences
  in dump format between major pg versions
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1925-cairn
superseded_by: null
created_at: '2026-06-11 20:31:18.035557+00:00'
updated_at: '2026-06-11 20:31:18.035558+00:00'
---

# pg-snapshot-drift-check-version-normalization

## description

Normalize Postgres version strings in schema snapshot files so drift checks pass across different pg minor versions running locally vs CI
