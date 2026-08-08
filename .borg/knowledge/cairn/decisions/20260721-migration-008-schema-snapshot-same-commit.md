---
id: 20260721-migration-008-schema-snapshot-same-commit
date: '2026-07-21'
project: cairn
domain: testing
tags:
- alembic
- migration
- schema-snapshot
- ci
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: null
created_at: '2026-07-21 22:17:44.753009+00:00'
updated_at: '2026-07-21 22:17:44.753009+00:00'
---

# 20260721-migration-008-schema-snapshot-same-commit

## decision

Refresh `docs/schema.snapshot.sql` in the same commit as Alembic migration 008

## context

Migration-Safety Engineer flagged that a stale snapshot creates a false sense of schema documentation accuracy and breaks any tooling that diffs against it.

## reasoning

Atomic commit keeps the snapshot truthful. Reviewers can see the exact schema change in the PR diff without running the migration locally.
