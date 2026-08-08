---
id: 20260415-separate-supabase-projects-per-app
date: '2026-06-11'
project: borg-collective
domain: infrastructure
tags:
- supabase
- portfolio
- isolation
- multi-tenant
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 22:41:19.239286+00:00'
updated_at: '2026-06-11 22:41:19.239287+00:00'
---

# 20260415-separate-supabase-projects-per-app

## decision

Use two separate Supabase projects (one per app) rather than a single shared project

## context

Both Waypoint and wallpaper-kit are being migrated to Supabase; decision on whether to share a single project for cost efficiency

## reasoning

Clean project separation ensures either app can be killed or sold independently without entangled schemas, auth configs, or RLS policies. The operational overhead of a second free-tier project is negligible.
