---
id: 20260611-fitness-invariant-no-direct-db-insert
date: '2026-06-11'
project: cairn
domain: testing
tags:
- fitness-functions
- invariants
- architecture-enforcement
- embeddings
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1925-cairn
created_at: '2026-06-11 20:31:18.034270+00:00'
updated_at: '2026-06-11 20:31:18.034271+00:00'
---

# 20260611-fitness-invariant-no-direct-db-insert

## decision

Add fitness invariant asserting no record_* function in cli.py/api.py/mcp.py calls db.insert_* directly

## context

The CLI→service consistency bug had existed silently — no test caught that CLI records lacked embeddings. A structural invariant prevents regression without requiring exhaustive behavioral tests for every future entry point.

## reasoning

Fitness functions that enforce architectural constraints at the code level catch bypass patterns before they ship. The invariant is cheap to run and precisely targets the failure mode that caused v0.2's primary bug.
