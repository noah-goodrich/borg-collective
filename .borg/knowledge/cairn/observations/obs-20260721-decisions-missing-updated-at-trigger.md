---
id: obs-20260721-decisions-missing-updated-at-trigger
session_date: '2026-07-21'
project: cairn
tool: claude-code
tags:
- postgresql
- triggers
- updated_at
- alembic
- decisions-table
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: null
superseded_by: null
created_at: '2026-07-24 03:53:11.046604+00:00'
updated_at: '2026-07-24 03:55:24.084484+00:00'
---

# obs-20260721-decisions-missing-updated-at-trigger

## content

The `decisions` table had an `updated_at` column (added in a prior PR) but no BEFORE UPDATE trigger calling set_updated_at(). The column existed silently returning stale insert-time values on every read. This was only discovered during the Codex migration audit when the belief VIEW needed age_seconds from all three atom tables.

## resolution

Migration 008 added the missing trigger for decisions (plus superseded_by columns and triggers for patterns/observations). Always cross-reference column existence against pg_trigger when auditing updated_at coverage — column presence alone is insufficient.
