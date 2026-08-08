---
id: obs-20260721-pg17-pg16-snapshot-byte-identical
session_date: '2026-07-21'
project: cairn
tool: claude-code
tags:
- postgresql
- pg_dump
- snapshot
- drift-check
- ci
- dev-environment
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: null
superseded_by: null
created_at: '2026-07-24 03:53:11.049619+00:00'
updated_at: '2026-07-24 03:55:24.084484+00:00'
---

# obs-20260721-pg17-pg16-snapshot-byte-identical

## content

The dev-postgres instance was upgraded to pg17 but pg_dump output matched CI's pg16-generated snapshot byte-for-byte on an empty baseline diff. The prior memory record `project_schema_snapshot_driftcheck` contained a stale workaround ('no pg_dump in container — patch CI's diff') that was no longer accurate.

## resolution

Updated the memory record with the clean regen recipe. When dev and CI postgres major versions differ, verify pg_dump compatibility empirically — pg17 client dumping a pg16-schema-format DB may still produce identical output. Don't assume a version mismatch means snapshot drift.
