---
id: obs-20260513-prod-write-auth-per-dispatch
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- prod
- authorization
- nanoprobes
- data-migration
- dispatch
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.429573+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260513-prod-write-auth-per-dispatch

## content

Each prod-write nanoprobe requires its own explicit authorization. A halted or previously-authorized dispatch does not carry forward authorization to subsequent dispatches in the same session or plan. Assuming a prior auth covers a new prod-write step will cause the dispatch to halt unexpectedly.

## resolution

Before any prod-write nanoprobe dispatch, confirm explicit authorization for that specific operation has been granted in the current context. Captured in feedback_prod_write_authorization.md in the cross-conversation store.
