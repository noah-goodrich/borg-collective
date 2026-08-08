---
id: obs-20260616-gitignore-negation-breakage
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- git
- gitignore
- negation
- silent-failure
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.429472+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260616-gitignore-negation-breakage

## content

An erroneous `.borg/` line in .gitignore was silently breaking the `!.borg/checkpoints/` negation rule. Git processes .gitignore rules top-to-bottom and a later positive rule cannot be un-done by an earlier negation — but more critically, a positive rule earlier in the file that matches a directory will suppress all negation rules for paths inside that directory that appear AFTER it. The result was that checkpoint files that were supposed to be tracked were being silently ignored with no error.

## resolution

Removed the erroneous `.borg/` line. When adding new ignore rules for a directory, grep the .gitignore for existing negation rules (`!path/`) that might be inside the newly ignored path, and restructure the rule order or scope to preserve intended negations.
