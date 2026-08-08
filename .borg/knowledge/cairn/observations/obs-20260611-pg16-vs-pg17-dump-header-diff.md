---
id: obs-20260611-pg16-vs-pg17-dump-header-diff
session_date: '2026-06-11'
project: cairn
tool: cursor
tags:
- postgres
- pg_dump
- schema-drift
- ci
- version-mismatch
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1925-cairn
superseded_by: null
created_at: '2026-06-11 23:12:50.743092+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-pg16-vs-pg17-dump-header-diff

## content

Schema drift checks comparing pg_dump snapshots between pg16 (CI) and pg17 (local dev) fail spuriously because pg_dump includes a version string in the dump header. The schemas are identical but the diff reports changes due to the version comment line.

## resolution

Normalize or strip pg_dump version headers before storing snapshots and before diffing in CI. Standardize on one Postgres version for CI or make the drift check version-agnostic.
