---
id: 20260715-backfill-dry-run-before-commit
date: '2026-07-15'
project: cairn
domain: data-migration
tags:
- backfill
- idempotency
- source-session
- safety
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: null
created_at: '2026-07-15 15:41:50.296675+00:00'
updated_at: '2026-07-15 15:41:50.296676+00:00'
---

# 20260715-backfill-dry-run-before-commit

## decision

Implement backfill commands with a mandatory dry-run mode, requiring --commit to write; verify dry-run before running with --commit in prod

## context

The backfill-source-session command touched 3000+ production records across decisions, patterns, and observations. A bad run could corrupt FK attribution at scale.

## reasoning

Dry-run first gives a preview of affected counts and catches logic errors (e.g., project-mismatch guards) before any writes occur. The idempotency guarantee (re-running updates 0) validates correctness after the fact.
