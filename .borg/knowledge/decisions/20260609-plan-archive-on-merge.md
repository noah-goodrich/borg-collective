---
id: 20260609-plan-archive-on-merge
date: '2026-06-11'
project: borg-collective
domain: code-quality
tags:
- project-management
- documentation
- conventions
- borg-assimilate
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 22:41:19.528055+00:00'
updated_at: '2026-06-11 22:41:19.528056+00:00'
---

# 20260609-plan-archive-on-merge

## decision

Remove PROJECT_PLAN.md from repo root on PR merge and archive the full plan (with all criteria checked and ship date) to docs/plans/assimilated/

## context

PR #41 merged the mechanism-layer extraction. The plan file had served its purpose and leaving it in root would accumulate stale plans over time.

## reasoning

Keeps repo root clean while preserving a permanent, auditable record of what was decided and when it shipped. Archived file becomes a reference parent for follow-on directives.
