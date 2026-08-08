---
id: 20260418-directive-vs-project-plan
date: '2026-06-11'
project: borg-collective
domain: architecture
tags:
- borg-collective
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
created_at: '2026-06-11 20:39:25.044735+00:00'
updated_at: '2026-06-11 20:39:25.044735+00:00'
---

# 20260418-directive-vs-project-plan

## decision

File cross-repo constraint documents under docs/plans/directives/ rather than as PROJECT_PLAN.md files

## context

The portfolio MVP pivot document governs work in two external repos (wayfinderai-waypoint, wallpaper-kit) but lives in borg-collective as the planning hub

## reasoning

A directive is a constraint/governance document, not an actionable plan for borg-collective itself. Separating directives from PROJECT_PLAN.md keeps the plan format reserved for in-repo executable work
