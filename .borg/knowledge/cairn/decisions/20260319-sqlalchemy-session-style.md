---
id: 20260319-sqlalchemy-session-style
date: '2026-06-11'
project: cairn
domain: architecture
tags:
- sqlalchemy
- database
- orm
- python
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1925-cairn
created_at: '2026-06-11 23:12:50.694357+00:00'
updated_at: '2026-06-11 23:12:50.694359+00:00'
---

# 20260319-sqlalchemy-session-style

## decision

Use SQLAlchemy 2.0 Session style (Session(engine) as context manager directly) rather than 1.x sessionmaker pattern

## context

Rewriting cairn's database layer from raw psycopg to SQLAlchemy 2.0; needed to choose which Session API style to adopt

## reasoning

Keeps things explicit and avoids legacy API confusion; SQLAlchemy 2.0 context manager style is idiomatic and doesn't require the extra factory indirection of sessionmaker
