---
id: 20260415-supabase-flyio-over-snowflake-spcs
date: '2026-06-11'
project: borg-collective
domain: infrastructure
tags:
- supabase
- fly.io
- snowflake
- postgres
- infrastructure
- cost
- portfolio
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 20:39:25.005948+00:00'
updated_at: '2026-06-11 20:39:25.005948+00:00'
---

# 20260415-supabase-flyio-over-snowflake-spcs

## decision

Pivot Waypoint and wallpaper-kit from Snowflake/MCP-first to Supabase + Fly.io for MVP validation

## context

Both apps were designed around Snowflake Postgres and SPCS but neither had users yet. Portfolio-level directive filed mid-session.

## reasoning

Snowflake Postgres costs ~$10/mo at Stage 1 with zero user benefit. SPCS is shaped for enterprise data workloads, not consumer SaaS. Supabase free tier handles 0–500 households at $0, removing infrastructure cost as a pre-launch blocker.
