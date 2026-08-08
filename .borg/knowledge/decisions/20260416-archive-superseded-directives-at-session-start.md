---
id: 20260416-archive-superseded-directives-at-session-start
date: '2026-06-11'
project: borg-collective
domain: project-management
tags:
- directives
- session-management
- borg-collective
- reveal
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 20:39:25.015803+00:00'
updated_at: '2026-06-11 20:39:25.015804+00:00'
---

# 20260416-archive-superseded-directives-at-session-start

## decision

Move superseded directive files to assimilated/ at the START of the next session, not immediately when they become stale.

## context

2026-04-14-supabase-flyio-mvp-pivot.md is superseded by PROJECT_PLAN.md but was not archived mid-session to avoid creating partial state.

## reasoning

Archiving mid-session creates a window where the directive is gone but the replacement hasn't been fully validated. Deferring to session start keeps the archive action atomic with the session's opening commit.
