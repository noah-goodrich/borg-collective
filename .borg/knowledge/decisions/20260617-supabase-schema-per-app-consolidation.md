---
id: 20260617-supabase-schema-per-app-consolidation
date: '2026-06-17'
project: borg-collective
domain: architecture
tags:
- supabase
- multi-tenant
- database
- auth
- stillpoint-platform
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260616-0347-orchestrator
created_at: '2026-06-17 18:01:10.016453+00:00'
updated_at: '2026-06-17 18:01:10.016456+00:00'
---

# 20260617-supabase-schema-per-app-consolidation

## decision

Target architecture is one `stillpoint-platform` Supabase project with schema-per-app isolation and shared `auth.users`, with reveal as a schema (not a split project).

## context

Two Supabase projects exist: `main` (shared by reveal/troth/stillpoint) and `ingle` (standalone). Need to decide consolidation direction before executing migration rebaseline.

## reasoning

Schema-per-app within a single project enables shared auth without cross-project IdP complexity, which is gated behind Team/Enterprise on Supabase Pro. Keeping reveal as a schema avoids a split-project auth federation problem.
