---
id: obs-20260616-gitignore-negation-unreachable
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- gitignore
- git
- negation
- directory-ignore
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.229230+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260616-gitignore-negation-unreachable

## content

A `!subdir/` negation rule in `.gitignore` is silently ineffective if a parent directory is already excluded by an earlier rule. Git will not un-ignore files inside an already-ignored directory. The `.borg/checkpoints/` exemption had been present in the repo for some time without ever working because `.borg/` appeared above it.

## resolution

Remove or narrow the parent directory ignore rule. In this case `.borg/` was removed entirely, relying on more specific ignore patterns instead so that `!.borg/checkpoints/` could take effect.
