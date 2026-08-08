---
id: 20260801-selective-uncommit-plan-artifacts
date: '2026-08-01'
project: borg-collective
domain: infrastructure
tags:
- git
- project-management
- checkpoints
- borg-workflow
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: cairn-backfill-commit
source_model: null
source_session: null
created_at: '2026-08-01 03:01:33.274970+00:00'
updated_at: '2026-08-01 03:01:33.274973+00:00'
---

# 20260801-selective-uncommit-plan-artifacts

## decision

Intentionally leave PROJECT_PLAN.md, .borg/research/i-have-adhd-2026-07-30.md, and prior .borg/checkpoints/* uncommitted to the PR branch

## context

PR #109 focused on docs sync to v0.8.9; ancillary planning and research artifacts existed but were not part of the sync objective

## reasoning

PROJECT_PLAN.md is destined for docs/plans/assimilated/ via /borg-assimilate post-merge — committing it pre-merge to the sync PR would require a follow-up move commit. Research notes and checkpoints are .borg/ internal artifacts not meant for the main tree.
