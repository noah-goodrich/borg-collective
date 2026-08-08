---
id: obs-20260723-prod-migration-lag
session_date: '2026-07-24'
project: cairn
tool: claude-code
tags:
- alembic
- deployment
- migration
- prod-lag
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: null
superseded_by: null
created_at: '2026-07-24 03:54:03.157593+00:00'
updated_at: '2026-07-24 03:55:24.084484+00:00'
---

# obs-20260723-prod-migration-lag

## content

Production cairn DB was at migration 007 and image 0.5.2 while main had migration 008 merged and tested. Migration 008 was not automatically applied to prod — the deploy gap meant prod schema diverged from the ORM expected by any code depending on the new columns (superseded_by, updated_at, set_updated_at trigger).

## resolution

Before starting PR-B's read layer (which queries the new columns), manually apply migration 008 to prod: `drone exec cairn -- env POSTGRES_DB=cairn alembic upgrade head`. Verify alembic_version updated. Migration is additive and safe for the running 0.5.2 image.
