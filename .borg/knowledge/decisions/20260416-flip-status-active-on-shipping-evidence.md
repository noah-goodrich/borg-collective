---
id: 20260416-flip-status-active-on-shipping-evidence
date: '2026-06-11'
project: borg-collective
domain: project-management
tags:
- project-status
- reveal
- planning
- deferred-debt
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 22:41:19.245758+00:00'
updated_at: '2026-06-11 22:41:19.245758+00:00'
---

# 20260416-flip-status-active-on-shipping-evidence

## decision

Flip reveal's Status from deferred/queued to Active based on evidence that the blocking work (Alembic/DB scaffolding) had already shipped.

## context

PROJECT_PLAN.md contained a stale deferral note ('queued behind Alembic work') that was never corrected after commit 2f3f1dd landed the persistence-layer scaffold. The project had been Active for some time without the plan reflecting it.

## reasoning

The deferral condition had been satisfied. The current Phase B work (archetype tuning, drama clamp, quality gate) is orthogonal to the DB layer — there was no architectural reason to keep the status as queued. Leaving it deferred would cause downstream planning errors (as it did here).
