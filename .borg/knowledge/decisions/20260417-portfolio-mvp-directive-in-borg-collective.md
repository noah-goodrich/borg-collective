---
id: 20260417-portfolio-mvp-directive-in-borg-collective
date: '2026-06-11'
project: borg-collective
domain: architecture
tags:
- cross-project
- coordination
- portfolio
- supabase
- fly.io
- directives
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 20:39:25.035776+00:00'
updated_at: '2026-06-11 20:39:25.035777+00:00'
---

# 20260417-portfolio-mvp-directive-in-borg-collective

## decision

Store cross-project coordination directives (portfolio-mvp-pivot) in borg-collective rather than in individual project repos

## context

The 2026-04-14-portfolio-mvp-pivot directive governs both Waypoint and wallpaper-kit — it doesn't belong to either project exclusively.

## reasoning

borg-collective is the meta-coordination layer; directives that span multiple projects have no better home than the workspace that tracks all of them.
