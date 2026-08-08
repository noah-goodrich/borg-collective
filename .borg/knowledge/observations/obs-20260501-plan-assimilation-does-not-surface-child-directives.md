---
id: obs-20260501-plan-assimilation-does-not-surface-child-directives
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- borg-assimilate
- directives
- orphan
- session-management
- workflow
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.241338+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260501-plan-assimilation-does-not-surface-child-directives

## content

When a parent plan is assimilated via `/borg-assimilate`, child directives spawned during that plan's execution are not automatically surfaced or checked. They silently become orphans — present in the directives directory but not linked, not tracked, and not visible at future session starts. The MVP plan for reveal was correctly assimilated 2026-05-01, but two child directives from the same execution window were missed entirely.

## resolution

Add child-check step to `/borg-assimilate`: scan directives dir for files referencing the assimilated plan's slug as `*Parent plan:*` and warn if any are unassimilated. Also surface via `borg-link-down` at session start.
