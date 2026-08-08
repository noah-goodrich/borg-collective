---
id: obs-20260611-production-migration-verify-before-smoke
session_date: '2026-06-11'
project: cairn
tool: cursor
tags:
- cairn
- migration
- postgres
- smoke-test
- production
category: pattern_discovered
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260611-1925-cairn
superseded_by: null
created_at: '2026-06-11 23:12:50.735155+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-production-migration-verify-before-smoke

## content

The production cairn DB must be confirmed at the correct migration head before running the smoke test. In this session, the DB was confirmed at 002_documents (head) before proceeding. Running the smoke test against a DB at the wrong migration level would produce misleading results (e.g., the documents table might not exist).

## resolution

Always run `drone exec cairn -- alembic current` (or equivalent) and confirm the head revision matches expectations before executing any smoke test against production.
