---
id: obs-20260611-hook-parity-asymmetry
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- hooks
- borg
- timeout
- parity
- shell-scripting
category: gotcha
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.348909+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-hook-parity-asymmetry

## content

When a pair of lifecycle hooks (start/end) are developed at different times, defensive guards (like `timeout`) added to one are easily missed on the other. The asymmetry is not obvious during code review because the hooks are in separate files and the omission doesn't cause a test failure until cairn hangs.

## resolution

Treat paired hooks as a single unit of review. When adding any guard to one hook, immediately check and apply the same guard to its counterpart.
