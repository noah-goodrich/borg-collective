---
id: obs-20260417-portfolio-mvp-infra-constraints
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- portfolio
- mvp
- supabase
- fly.io
- cost
- constraints
- waypoint
- wallpaper-kit
category: domain_knowledge
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 20:39:25.037862+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260417-portfolio-mvp-infra-constraints

## content

The portfolio MVP directive for both Waypoint and wallpaper-kit codifies hard constraints: Supabase + Fly.io only (no Snowflake, no Clerk in MVP), total infra cost ≤ $25/month. This is a binding decision recorded in `docs/plans/directives/2026-04-14-portfolio-mvp-pivot.md`.

## resolution

Before introducing any new infrastructure dependency to Waypoint or wallpaper-kit, validate against this directive. Any deviation requires explicit superseding directive.
