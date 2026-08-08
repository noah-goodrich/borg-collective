---
id: 20260709-schema-snapshot-patch-workaround
date: '2026-07-09'
project: cairn
domain: infrastructure
tags:
- ci
- schema-snapshot
- alembic
- pg_dump
- workaround
alternatives: []
applies_to: []
confidence: 0.9
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260709-1535-cairn
created_at: '2026-07-09 15:36:29.693024+00:00'
updated_at: '2026-07-09 15:36:29.693025+00:00'
---

# 20260709-schema-snapshot-patch-workaround

## decision

Regenerate docs/schema.snapshot.sql by normalizing and patch-applying CI's own diff output rather than running pg_dump inside the container

## context

CI schema-snapshot drift check failed after migration 005 was added. pg_dump was unavailable inside the CI container, and version skew between local and CI postgres produced non-deterministic dump output.

## reasoning

The diff CI produced was the ground truth about what was missing. Applying it directly to the snapshot avoided the pg_dump toolchain problem entirely.
