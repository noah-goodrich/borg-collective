---
id: obs-20260513-prod-write-auth-not-inherited
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- prod-write
- authorization
- nanoprobe
- workflow
- safety
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.378690+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260513-prod-write-auth-not-inherited

## content

Production-write authorization does not carry forward between dispatched nanoprobes. Each prod-write nanoprobe requires its own explicit authorization grant. A halted dispatch that received auth does not transfer that auth to a subsequent re-dispatch or parallel probe.

## resolution

Before dispatching any nanoprobe that will write to prod, explicitly re-authorize that specific probe. Do not assume a prior 'yes' covers the current operation. Captured in feedback_prod_write_authorization.md.
