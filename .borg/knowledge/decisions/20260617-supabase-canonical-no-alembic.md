---
id: 20260617-supabase-canonical-no-alembic
date: '2026-06-17'
project: borg-collective
domain: infrastructure
tags:
- supabase
- migrations
- alembic
- database
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260616-0347-orchestrator
created_at: '2026-06-17 18:01:10.020357+00:00'
updated_at: '2026-06-17 18:01:10.020358+00:00'
---

# 20260617-supabase-canonical-no-alembic

## decision

Supabase CLI (`db push`) is the canonical migration tool in production — Alembic is not used.

## context

Needed to verify migration toolchain before deciding how to execute the consolidation rebaseline.

## reasoning

Fact-checked during session — no Alembic present in prod. Supabase CLI is the authoritative source. Rebaseline should use `supabase db pull` to establish baseline, not blind repair.
