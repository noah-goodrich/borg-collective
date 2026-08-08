---
id: obs-20260714-schema-drift-check-red-since-22
session_date: '2026-07-14'
project: cairn
tool: claude-code
tags:
- alembic
- migration
- schema-snapshot
- drift-check
- ci
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260714-0405-cairn
superseded_by: null
created_at: '2026-07-14 04:06:54.533403+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260714-schema-drift-check-red-since-22

## content

The drift-check CI gate had been RED since PR #22 (which added migration 006 / `call_log_id`) because the snapshot refresh step was omitted from that PR. The failure was on the drift-check job, not on the migration job itself, so it was not caught at merge time and silently blocked all subsequent PRs until explicitly triaged.

## resolution

Refreshed `docs/schema.snapshot.sql` for migration 006 in cairn #27, greening the gate. Going forward, snapshot refresh must be part of every migration PR or an immediate follow-up before the next PR is opened.
