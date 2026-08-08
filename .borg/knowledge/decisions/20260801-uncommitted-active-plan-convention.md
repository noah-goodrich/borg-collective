---
id: 20260801-uncommitted-active-plan-convention
date: '2026-08-01'
project: borg-collective
domain: infrastructure
tags:
- project-plan
- git
- workflow
- borg-assimilate
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: cairn-backfill-commit
source_model: null
source_session: null
created_at: '2026-08-01 02:47:55.474029+00:00'
updated_at: '2026-08-01 02:47:55.474033+00:00'
---

# 20260801-uncommitted-active-plan-convention

## decision

PROJECT_PLAN.md intentionally left uncommitted to git — it lives as an active working artifact until /borg-assimilate moves it to docs/plans/assimilated/ on completion.

## context

PROJECT_PLAN.md was written to track the docs-sync work. PR #109 was committed and pushed, but PROJECT_PLAN.md was deliberately excluded from that commit.

## reasoning

Active plans are transient working documents. Committing them to the feature branch and then immediately archiving creates git noise. The borg-assimilate lifecycle handles archival after merge, keeping the main branch clean.
