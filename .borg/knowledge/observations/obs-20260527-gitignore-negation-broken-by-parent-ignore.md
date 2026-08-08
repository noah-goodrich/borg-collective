---
id: obs-20260527-gitignore-negation-broken-by-parent-ignore
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- gitignore
- git
- setup
- checkpoints
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.494359+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260527-gitignore-negation-broken-by-parent-ignore

## content

Adding .borg/ to .gitignore breaks any !.borg/checkpoints/ negation rule. Git does not descend into ignored directories to evaluate negation patterns, so checkpoints silently become untracked even when the negation rule is present. The bug existed silently until the state.json migration made the gitignore entry worth re-examining.

## resolution

Changed cmd_setup to add .borg/state.json specifically instead of .borg/. Any other files under .borg/ that should be ignored need their own explicit entries. Document this constraint in setup code comments.
