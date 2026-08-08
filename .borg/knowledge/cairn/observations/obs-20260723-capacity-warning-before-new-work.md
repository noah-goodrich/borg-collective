---
id: obs-20260723-capacity-warning-before-new-work
session_date: '2026-07-24'
project: cairn
tool: claude-code
tags:
- project-management
- borg
- capacity
category: pattern_discovered
files_involved: []
confidence: 0.7
source_model: null
source_session: null
superseded_by: null
created_at: '2026-07-24 05:15:46.528582+00:00'
updated_at: '2026-07-24 05:15:48.186761+00:00'
---

# obs-20260723-capacity-warning-before-new-work

## content

Session opened with a 4-projects-vs-3 warning indicating project capacity was at risk. This is a signal to run `borg-next` before starting new work, not after.

## resolution

Check capacity warnings at session start. Run `borg-next` to triage before beginning new project phases, especially after shipping a phase that closes work and opens new options.
