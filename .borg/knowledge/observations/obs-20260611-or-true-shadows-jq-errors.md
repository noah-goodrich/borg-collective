---
id: obs-20260611-or-true-shadows-jq-errors
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- shell
- jq
- error-handling
- silent-failure
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.502578+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-or-true-shadows-jq-errors

## content

Appending || true to a jq pipeline that builds a JSONL record masks all jq syntax errors, type errors, and missing-field errors. The script continues and writes an empty or malformed line to the log, which later causes silent parse failures in consumers.

## resolution

Remove || true from jq build commands. Let the pipeline fail loudly so errors surface during testing. Use explicit default values inside jq (e.g., // "") rather than suppressing failures at the shell level.
