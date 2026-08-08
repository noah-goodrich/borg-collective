---
id: 20260721-codex-two-pr-shape
date: '2026-07-21'
project: cairn
domain: architecture
tags:
- codex
- pull-request-strategy
- migration
- belief-store
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: null
created_at: '2026-07-21 22:17:44.750922+00:00'
updated_at: '2026-07-21 22:17:44.750923+00:00'
---

# 20260721-codex-two-pr-shape

## decision

Codex Phase 1a is split into two PRs: PR-A (schema migration 008 only) and PR-B (belief VIEW + contradiction query + `/belief/*` endpoints + review-queue state machine)

## context

Scope Hawk and Skeptic flagged that combining schema migration with application logic in one PR would make rollback harder and blur the migration safety review.

## reasoning

Isolating the Alembic migration in PR-A means the downgrade test and schema snapshot can be reviewed independently. PR-B can then assume a stable schema and focus on query correctness and API behaviour.
