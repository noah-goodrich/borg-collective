---
id: 20260415-supabase-over-snowflake-stage1
date: '2026-06-11'
project: borg-collective
domain: infrastructure
tags:
- supabase
- snowflake
- fly.io
- portfolio-strategy
- mvp
- cost
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 22:41:19.231187+00:00'
updated_at: '2026-06-11 22:41:19.231188+00:00'
---

# 20260415-supabase-over-snowflake-stage1

## decision

Pivot Waypoint and wallpaper-kit MVPs from Snowflake Postgres + SPCS to Supabase + Fly.io.

## context

Portfolio directive filed mid-session after Cortex evaluation of infrastructure options for two consumer-facing apps at Stage 1 (0–500 users).

## reasoning

Snowflake incurs ~$10/mo regardless of usage (loyalty tax with no user-facing benefit at Stage 1). SPCS is architected for steady enterprise workloads, wrong shape for bursty consumer traffic. Supabase free tier handles the target user range at $0 and includes auth, realtime, and storage primitives needed for both apps.
