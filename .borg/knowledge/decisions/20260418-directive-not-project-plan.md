---
id: 20260418-directive-not-project-plan
date: '2026-06-11'
project: borg-collective
domain: architecture
tags:
- docs
- planning
- cross-repo
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
created_at: '2026-06-11 22:41:19.266662+00:00'
updated_at: '2026-06-11 22:41:19.266663+00:00'
---

# 20260418-directive-not-project-plan

## decision

File cross-repo constraint documents under `docs/plans/directives/` rather than as `PROJECT_PLAN.md` files

## context

A portfolio-level pivot document governs work in two external repos (wayfinderai-waypoint, wallpaper-kit) but lives in borg-collective as the coordination hub.

## reasoning

A directive is a constraint/governing document, not an execution plan for borg-collective itself. Separating the types prevents conflating 'what this repo does' with 'what this document constrains across repos'.
