---
id: 20260616-archive-plan-with-shipped-date
date: '2026-06-16'
project: borg-collective
domain: documentation
tags:
- documentation
- project-plan
- archival
- convention
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260616-0347-orchestrator
created_at: '2026-06-16 10:27:02.428169+00:00'
updated_at: '2026-06-16 10:27:02.428170+00:00'
---

# 20260616-archive-plan-with-shipped-date

## decision

Archive completed plan documents by moving them to docs/plans/assimilated/ with a renamed slug reflecting original date, and prepend 'Shipped: YYYY-MM-DD' to the file

## context

PROJECT_PLAN.md was complete and needed to be removed from the active plans directory without losing the historical record

## reasoning

Keeps active plans directory clean while preserving full history and making shipped date immediately visible without opening the file. The rename to a date-prefixed slug makes the archive scannable.
