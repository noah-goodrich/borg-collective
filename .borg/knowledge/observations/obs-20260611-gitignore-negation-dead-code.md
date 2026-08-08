---
id: obs-20260611-gitignore-negation-dead-code
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- gitignore
- negation
- directory-exclusion
- silent-failure
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.348228+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-gitignore-negation-dead-code

## content

A `.gitignore` negation rule for a subdirectory (`!.borg/checkpoints/`) is silently ignored when a parent-directory exclusion rule (`.borg/`) appears anywhere before it. Git will not track the exempted subdirectory, and there is no warning — the file simply behaves as if the negation line doesn't exist.

## resolution

Remove the parent-directory blanket rule. If some other subdirectories under `.borg/` still need to be ignored, enumerate them explicitly instead of using a parent wildcard.
