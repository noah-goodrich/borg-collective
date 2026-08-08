---
id: obs-20260616-jq-or-true-error-shadow
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- jq
- shell
- error-handling
- jsonl
- hooks
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.467928+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260616-jq-or-true-error-shadow

## content

Adding '|| true' to a jq pipeline that builds a JSONL record silently swallows jq parse/construction errors. If jq fails (malformed input, bad filter), the record is never written, the hook exits 0, and the failure is invisible — no JSONL entry, no log, no signal.

## resolution

Remove '|| true' from jq record-building pipelines in hooks. Let jq failures propagate so they surface in hook stderr output or test failures. Use explicit guards (empty-check on inputs) before calling jq rather than suppressing its exit code.
