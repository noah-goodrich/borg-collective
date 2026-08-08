---
id: 20260415-two-supabase-projects-not-shared
date: '2026-06-11'
project: borg-collective
domain: infrastructure
tags:
- supabase
- portfolio
- multi-tenant
- architecture
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
created_at: '2026-06-11 20:39:24.988240+00:00'
updated_at: '2026-06-11 20:39:24.988241+00:00'
---

# 20260415-two-supabase-projects-not-shared

## decision

Waypoint and wallpaper-kit each get separate Supabase projects rather than sharing one.

## context

Portfolio pivot dropped Snowflake Postgres + SPCS in favor of Supabase + Fly.io for both MVPs. Question arose whether to consolidate DB costs under a single Supabase org project.

## reasoning

Keeping apps independently sellable requires clean separation of data, auth tenants, and billing. A shared project entangles the two products and complicates any future acquisition, spin-off, or shut-down of one without the other.
