---
id: obs-20260616-commit-not-directive
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- directives
- audit
- git
- false-closure
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.555512+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260616-commit-not-directive

## content

Commit #48 was associated in memory with the reaper-TZ directive but was actually a `stat`-based fix unrelated to the TZ bug. The directive had been left open correctly, but the existence of a nearby commit with a related filename created a false impression of completion during a quick scan.

## resolution

Adversarial verify step: always read the actual diff of the candidate commit, not just its message or the files it touches, before marking a directive DONE.
