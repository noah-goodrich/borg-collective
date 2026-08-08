---
id: 20260319-ddl-in-alembic-not-metadata
date: '2026-06-11'
project: cairn
domain: architecture
tags:
- alembic
- sqlalchemy
- schema
- migrations
- orm
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1925-cairn
created_at: '2026-06-11 23:12:50.695662+00:00'
updated_at: '2026-06-11 23:12:50.695663+00:00'
---

# 20260319-ddl-in-alembic-not-metadata

## decision

Keep all DDL exclusively in Alembic migrations rather than using Base.metadata.create_all(); ORM models exist only for type-safe inserts

## context

When introducing Alembic alongside SQLAlchemy ORM models, had to decide which is the authoritative source of truth for the DB schema

## reasoning

Prevents drift between ORM model definitions and actual database schema; migration files are the single source of truth and produce a reproducible, version-controlled schema
