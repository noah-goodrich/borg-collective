---
id: 20260414-snowflake-out-supabase-flyio-mvp
date: '2026-06-11'
project: borg-collective
domain: infrastructure
tags:
- supabase
- fly.io
- snowflake
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
created_at: '2026-06-11 20:39:25.022836+00:00'
updated_at: '2026-06-11 20:39:25.022837+00:00'
---

# 20260414-snowflake-out-supabase-flyio-mvp

## decision

Replace Snowflake/Cortex/SPCS with Supabase free tier + Fly.io for both Waypoint and wallpaper-kit MVPs. Revisit gate set at ≥1K paying users.

## context

Evaluating infra stack for two early-stage apps. Cortex Code evaluation surfaced concrete cost floor numbers for Snowflake path.

## reasoning

Snowflake Postgres costs ~$10/mo with zero user benefit at Stage 1. SPCS adds $50/mo warm-pool floor plus 10–30s cold starts — unacceptable UX for mobile-first apps with no paying users yet. Combined infra cap is ≤$25/mo pre-launch.
