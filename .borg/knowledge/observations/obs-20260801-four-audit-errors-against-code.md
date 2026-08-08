---
id: obs-20260801-four-audit-errors-against-code
session_date: '2026-08-01'
project: borg-collective
tool: claude-code
tags:
- audit
- documentation
- presence
- six-pager
- drone
- postCreate
category: error_encountered
files_involved: []
confidence: 0.9
source_model: null
source_session: null
superseded_by: null
created_at: '2026-08-01 03:01:33.467780+00:00'
updated_at: '2026-08-01 03:01:33.467785+00:00'
---

# obs-20260801-four-audit-errors-against-code

## content

Four distinct audit errors were caught when docs were checked against live code: (1) presence feature described as non-real was actually real, (2) six-pager document referenced as missing actually exists, (3) drone feature/toggle/fix categorization was wrong in docs, (4) postCreate lesson was undocumented. Each represents a case where docs asserted a false state about the codebase.

## resolution

All four corrected in PR #109 (+649/-95 line delta reflects the scope of corrections). Root cause: docs had not been audited against code since before v0.8.9; incremental code changes outpaced doc updates.
