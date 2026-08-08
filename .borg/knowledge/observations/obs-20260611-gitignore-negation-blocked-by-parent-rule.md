---
id: obs-20260611-gitignore-negation-blocked-by-parent-rule
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- git
- gitignore
- negation-rules
- file-tracking
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.468987+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-gitignore-negation-blocked-by-parent-rule

## content

A bare `.borg/` entry in .gitignore was silently preventing the negation rule `!.borg/checkpoints/` from working. Git processes .gitignore rules top-to-bottom; once a directory is excluded, no later negation rule can re-include files inside it unless the directory itself is re-included first.

## resolution

Removed the erroneous `.borg/` rule and replaced it with more specific ignore patterns, allowing `!.borg/checkpoints/` to function as intended. General fix: when a negation rule appears not to work, check if a parent directory is being excluded by an earlier rule — you must un-exclude the parent before you can negate children.
