---
id: 20260611-archive-plan-with-shipped-date
date: '2026-06-11'
project: borg-collective
domain: documentation
tags:
- project-management
- documentation
- git
- plans
- archival
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 22:41:19.467970+00:00'
updated_at: '2026-06-11 22:41:19.467970+00:00'
---

# 20260611-archive-plan-with-shipped-date

## decision

Archive completed plan documents by moving them to docs/plans/assimilated/ and prepending a 'Shipped: YYYY-MM-DD' marker rather than deleting them

## context

PROJECT_PLAN.md and dev audit directive needed to be retired after completion

## reasoning

Preserves the historical record of what was planned and when it shipped; assimilated/ directory makes it easy to distinguish active from completed plans without cluttering the active plans directory
