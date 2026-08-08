---
id: obs-20260415-snowflake-cost-shape-mismatch-stage1
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- snowflake
- supabase
- infrastructure
- cost
- spcs
- consumer-apps
- portfolio
category: domain_knowledge
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 20:39:24.990772+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260415-snowflake-cost-shape-mismatch-stage1

## content

Cortex evaluation concluded that Snowflake Postgres + SPCS is the wrong infrastructure shape for bursty consumer traffic at Stage 1. Cost floor is ~$10/mo regardless of usage (a loyalty tax with no user-facing benefit at 0–500 households). SPCS is optimized for analytical/batch workloads, not the request pattern of a consumer PWA. Supabase free tier handles the same 0–500 household range at $0 with a Postgres-compatible API and built-in auth.

## resolution

Pivoted both Waypoint and wallpaper-kit MVPs to Supabase + Fly.io. Snowflake remains available for analytical workloads if the portfolio reaches a scale where it earns its cost. This is a Stage 1 / Stage N distinction, not a permanent rejection of Snowflake.
