---
id: obs-20260611-directive-commit-hash-conflation
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- directives
- backlog
- commit-tracking
- false-closure
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.561663+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-directive-commit-hash-conflation

## content

A directive (reaper-TZ, 2026-06-06) had been associated with commit #48 in backlog notes, but commit #48 fixed a `stat`-related issue — not the UTC parsing bug. The directive was never actually resolved. Without adversarial verification against the actual code, this would have stayed falsely 'done' indefinitely.

## resolution

When a directive cites a commit as its fix, verify by reading the diff of that exact commit against the directive's acceptance criteria. Do not rely on commit message similarity or proximity in time.
