---
id: 20260611-plan-assimilation-over-claude-md
date: '2026-06-11'
project: cairn
domain: project-management
tags:
- documentation
- project-plan
- assimilate-workflow
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1925-cairn
created_at: '2026-06-11 20:31:18.016180+00:00'
updated_at: '2026-06-11 20:31:18.016181+00:00'
---

# 20260611-plan-assimilation-over-claude-md

## decision

Moved PROJECT_PLAN.md into docs/plans/assimilated/ with closeout notes rather than keeping it at the repo root; de-triaged CLAUDE.md.

## context

Assimilate gate surfaced that the triage notes in CLAUDE.md and the root PROJECT_PLAN.md were stale now that v0.1.0 shipped.

## reasoning

Keeping closed plans in an assimilated/ directory preserves history without cluttering the active workspace. CLAUDE.md should only contain current-state guidance, not historical triage.
