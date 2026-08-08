---
id: obs-20260617-amazon-csv-silent-zero-import
session_date: '2026-06-17'
project: borg-collective
tool: claude-code
tags:
- ingle
- amazon
- csv
- import
- canonicalization
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-17 18:01:10.025625+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260617-amazon-csv-silent-zero-import

## content

Amazon CSV imports were silently succeeding (no error) but importing 0 orders. The root cause was a canonicalization mismatch — the CSV parser was not handling Amazon's specific field format/encoding, so all rows were rejected silently rather than failing loudly.

## resolution

Fixed in ingle PR #100 with canonicalization hardening. Any CSV import pipeline should validate that row count ingested matches row count in source file, not just that no exception was thrown.
