---
id: 20260721-belief-view-outside-sqlalchemy-autoload
date: '2026-07-24'
project: cairn
domain: architecture
tags:
- sqlalchemy
- views
- migrations
- alembic
- codex
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: null
created_at: '2026-07-24 03:53:11.040894+00:00'
updated_at: '2026-07-24 03:55:23.802040+00:00'
---

# 20260721-belief-view-outside-sqlalchemy-autoload

## decision

Expose the belief typed-VIEW via raw SQL in service.py, keeping it OUT of the SQLAlchemy autoload path

## context

PR-B requires a 3-way UNION VIEW over decisions ∪ patterns ∪ observations. The view needs to be queryable but could interfere with Alembic's migration ordering if autoloaded.

## reasoning

Migration-ordering safety: if SQLAlchemy autoloads the view, schema introspection during migrations may fail or produce spurious diffs. Raw SQL in service.py avoids this coupling entirely.
