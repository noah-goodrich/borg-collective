---
id: 20260416-supabase-migration-last-mile-not-blocker
date: '2026-06-11'
project: borg-collective
domain: infrastructure
tags:
- supabase
- postgresql
- reveal
- migration
- fly.io
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 20:39:25.015304+00:00'
updated_at: '2026-06-11 20:39:25.015305+00:00'
---

# 20260416-supabase-migration-last-mile-not-blocker

## decision

Classify the reveal-postgres → Supabase external-network swap as 'last mile' infrastructure, not 'pre-revenue mid-stream disruption'.

## context

The Supabase migration was previously framed as a significant mid-stream interruption that justified deferring project status to queued. On review, it is a localized connection-string swap after Alembic scaffolding already shipped.

## reasoning

The persistence layer scaffolding was one-shot setup (commit 2f3f1dd). Current Phase B work (archetype tuning, drama clamp, quality gate) is orthogonal to the DB layer. The migration is a deployment step, not a development blocker.
