---
id: 20260319-sqlalchemy-session-direct
date: '2026-06-11'
project: cairn
domain: architecture
tags:
- sqlalchemy
- database
- python
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
created_at: '2026-06-11 20:31:17.971470+00:00'
updated_at: '2026-06-11 20:31:17.971487+00:00'
---

# 20260319-sqlalchemy-session-direct

## decision

Use SQLAlchemy 2.0 Session(engine) directly as a context manager rather than 1.x sessionmaker pattern

## context

Replacing raw psycopg with SQLAlchemy required choosing a session management style

## reasoning

Keeps code explicit and avoids legacy API confusion; SQLAlchemy 2.0 style is cleaner and more transparent about session lifecycle
