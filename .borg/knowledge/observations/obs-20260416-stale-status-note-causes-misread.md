---
id: obs-20260416-stale-status-note-causes-misread
session_date: '2026-04-16'
project: borg-collective
tool: cursor
tags:
- project-status
- planning
- reveal
- deferral
- stale-docs
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.248608+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260416-stale-status-note-causes-misread

## content

A deferral note in PROJECT_PLAN.md ('queued behind Alembic work') was never removed after the Alembic scaffolding shipped in commit 2f3f1dd. This caused a full planning session to be spent correcting an under-reading of the project's shipping state — work that had already been done (4-pass pipeline, 6 archetypes, 189 passing tests, business artifacts) was not reflected in the plan, making the project appear less mature than it was.

## resolution

After any commit that resolves a stated blocker, immediately update the plan's status note. Treat any deferral note encountered during a planning session as requiring explicit verification against git history before accepting it.
