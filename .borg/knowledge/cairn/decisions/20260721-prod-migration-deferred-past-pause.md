---
id: 20260721-prod-migration-deferred-past-pause
date: '2026-07-24'
project: cairn
domain: infrastructure
tags:
- alembic
- migrations
- production
- deployment
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
created_at: '2026-07-24 03:53:11.043785+00:00'
updated_at: '2026-07-24 03:55:23.802040+00:00'
---

# 20260721-prod-migration-deferred-past-pause

## decision

Deliberately defer applying migration 008 to the shared prod cairn-api DB until PR-B's read layer is ready to go live, rather than applying it immediately after merge

## context

Migration 008 is additive and safe for the currently deployed image (raw-SQL reads, explicit-column inserts), but applying an unprompted prod migration at a natural pause point was deemed undesirable.

## reasoning

Additive migrations are safe to batch with the next meaningful deploy. Applying prod migrations at arbitrary pause points introduces operational noise and a deployment event without a corresponding feature going live. Deferring keeps the migration paired with the code that depends on it.
