---
id: 20260721-belief-view-excluded-from-sa-autoload
date: '2026-07-21'
project: cairn
domain: infrastructure
tags:
- sqlalchemy
- sql-view
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
created_at: '2026-07-21 22:17:44.752529+00:00'
updated_at: '2026-07-21 22:17:44.752530+00:00'
---

# 20260721-belief-view-excluded-from-sa-autoload

## decision

The belief VIEW must be kept out of the SQLAlchemy autoload/reflection path

## context

DB Architect and Migration-Safety Engineer roles in the Collective review flagged that Alembic's autogenerate will attempt to diff VIEWs it discovers via reflection, producing spurious migration operations.

## reasoning

Prevents Alembic autogenerate from emitting DROP/CREATE VIEW noise in unrelated migrations. VIEW DDL is managed explicitly in its own migration script.
