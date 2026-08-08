---
id: 20260414-snowflake-out-of-mvp
date: '2026-06-11'
project: borg-collective
domain: infrastructure
tags:
- snowflake
- supabase
- fly.io
- mvp
- cost-optimization
- waypoint
- wallpaper-kit
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 22:41:19.253441+00:00'
updated_at: '2026-06-11 22:41:19.253442+00:00'
---

# 20260414-snowflake-out-of-mvp

## decision

Fully remove Snowflake/Cortex/SPCS from the MVP path for both Waypoint and wallpaper-kit. Use Supabase free tier instead.

## context

Cortex Code evaluation revealed Snowflake Postgres costs ~$10/mo with no user-facing benefit at Stage 1. SPCS adds a $50/mo warm-pool floor plus 10–30s cold starts.

## reasoning

Cost/benefit is negative at Stage 1. Zero user benefit justifies zero spend. Revisit gate set at ≥1K paying users, when the economics change.
