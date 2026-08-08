---
id: 20260611-archive-plan-on-ship
date: '2026-06-11'
project: borg-collective
domain: project-management
tags:
- documentation
- plan-lifecycle
- archival
- borg-conventions
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 22:41:19.476819+00:00'
updated_at: '2026-06-11 22:41:19.476819+00:00'
---

# 20260611-archive-plan-on-ship

## decision

Archive PROJECT_PLAN.md to docs/plans/assimilated/ with a renamed file reflecting the original plan date and title, stamped with 'Shipped: YYYY-MM-DD'.

## context

PROJECT_PLAN.md had been superseded; the borg-collective convention needed to be applied to retire it cleanly without losing history.

## reasoning

Moving to assimilated/ with a datestamped name preserves full history and makes the archive browsable by ship date. The 'Shipped' stamp makes it immediately clear the plan is complete rather than abandoned.
