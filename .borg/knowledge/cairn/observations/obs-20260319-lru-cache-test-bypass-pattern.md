---
id: obs-20260319-lru-cache-test-bypass-pattern
session_date: '2026-03-19'
project: cairn
tool: cursor
tags:
- sqlalchemy
- python
- testing
- lru_cache
- alembic
category: pattern_discovered
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260611-1925-cairn
superseded_by: null
created_at: '2026-06-11 20:31:17.988741+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260319-lru-cache-test-bypass-pattern

## content

When get_engine() is decorated with lru_cache, tests that need a different database URL (e.g., cairn_test instead of cairn) cannot simply change the environment variable — the cached engine will still point to the original URL. The clean solution is to pass the test URL via Alembic's sqlalchemy.url config key and construct a NullPool engine from it inside env.py, bypassing get_engine() entirely.

## resolution

In alembic/env.py, check for a sqlalchemy.url config override; if present, build a NullPool engine from that URL instead of calling get_engine(). Tests set this config key before invoking alembic commands.
