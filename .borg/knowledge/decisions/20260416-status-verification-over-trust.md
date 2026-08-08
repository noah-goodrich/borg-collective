---
id: 20260416-status-verification-over-trust
date: '2026-06-11'
project: borg-collective
domain: project-management
tags:
- project-plan
- status-tracking
- reveal
- technical-debt
alternatives: []
applies_to: []
confidence: 0.9
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 20:39:25.014829+00:00'
updated_at: '2026-06-11 20:39:25.014830+00:00'
---

# 20260416-status-verification-over-trust

## decision

Treat any 'deferred' or 'queued' status note in a PROJECT_PLAN as a flag requiring verification, not a fact to accept at face value.

## context

reveal's PROJECT_PLAN.md had a stale deferral note ('queued behind Alembic work') that was never corrected after the DB scaffolding shipped. This caused the project to be under-read as inactive when it was actively shipping features.

## reasoning

Deferral notes are written at a point in time and rarely get updated when the blocker resolves. Treating them as verified truth causes systematic mis-assessment of project state.
