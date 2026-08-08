---
id: 20260414-separate-supabase-projects
date: '2026-06-11'
project: borg-collective
domain: infrastructure
tags:
- supabase
- multi-tenant
- portfolio
- exit-strategy
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
created_at: '2026-06-11 22:41:19.253885+00:00'
updated_at: '2026-06-11 22:41:19.253886+00:00'
---

# 20260414-separate-supabase-projects

## decision

Provision two separate Supabase projects — one per app — rather than a shared project.

## context

Both Waypoint and wallpaper-kit are portfolio apps that may be sold or shut down independently.

## reasoning

Clean kill/sell boundary: either app can exit without entangling the other's data or billing.
