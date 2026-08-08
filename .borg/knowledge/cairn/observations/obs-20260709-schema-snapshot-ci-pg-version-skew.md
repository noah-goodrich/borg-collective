---
id: obs-20260709-schema-snapshot-ci-pg-version-skew
session_date: '2026-07-09'
project: cairn
tool: claude-code
tags:
- ci
- schema-snapshot
- pg_dump
- version-skew
- docker
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260709-1535-cairn
superseded_by: null
created_at: '2026-07-09 15:36:29.700751+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260709-schema-snapshot-ci-pg-version-skew

## content

CI schema-snapshot drift check uses pg_dump output for comparison. pg_dump is not available inside the CI container, and even when available locally, version differences between local postgres and CI postgres produce formatting/ordering differences that make naive diff-based snapshot checks non-deterministic.

## resolution

Normalize the snapshot format and apply CI's own diff output directly to the snapshot file (patch-based approach). This sidesteps the pg_dump toolchain entirely and makes the snapshot update deterministic. Memory: project_schema_snapshot_driftcheck.
