---
id: obs-20260617-ingle-multimb-body-size-failure
session_date: '2026-06-17'
project: borg-collective
tool: claude-code
tags:
- ingle
- import
- http
- body-size
- csv
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-17 18:01:10.025960+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260617-ingle-multimb-body-size-failure

## content

Multi-MB Amazon CSV uploads were failing with an opaque error. The failure mode was not a helpful 413 but an obscure/generic error that didn't indicate body size as the cause.

## resolution

Fixed in ingle PR #100. When diagnosing opaque import failures on large files, check HTTP body size limits as a first hypothesis — the error message may not point there directly.
