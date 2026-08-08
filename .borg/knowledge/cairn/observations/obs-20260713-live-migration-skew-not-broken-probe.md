---
id: obs-20260713-live-migration-skew-not-broken-probe
session_date: '2026-07-13'
project: cairn
tool: claude-code
tags:
- readiness-probe
- migrations
- deployment
- '503'
- alembic
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260713-2223-cairn
superseded_by: null
created_at: '2026-07-13 22:50:48.703617+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260713-live-migration-skew-not-broken-probe

## content

During the session, /ready was returning 503. Initial interpretation risk: assume the probe is misconfigured or broken. Actual cause: DB was at migration 006 but deployed image expected 005. The probe was working correctly — it was detecting a real incompatibility.

## resolution

Before debugging a failing readiness probe, always compare the live DB migration version against the version the deployed image was built against. A 503 during a pending deploy is expected and correct behavior.
