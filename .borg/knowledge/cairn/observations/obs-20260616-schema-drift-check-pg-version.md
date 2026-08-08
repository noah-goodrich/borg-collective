---
id: obs-20260616-schema-drift-check-pg-version
session_date: '2026-06-16'
project: cairn
tool: claude-code
tags:
- cairn
- postgres
- schema
- migration
- ci
- portability
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260616-0914-cairn
superseded_by: null
created_at: '2026-06-16 10:27:02.544534+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260616-schema-drift-check-pg-version

## content

The cairn schema drift-check was not portable across PostgreSQL versions — it passed on the local PG version but failed in CI which ran a different version. The check used PG-version-specific output format assumptions.

## resolution

Made the drift-check pg-version-portable in cairn PR #6.
