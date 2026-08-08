---
id: obs-20260611-gitignore-erroneous-borg-line
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- gitignore
- borg
- .borg
- untracked-files
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.478175+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-gitignore-erroneous-borg-line

## content

The .gitignore contained an erroneous '.borg/' entry that was incorrectly suppressing tracking of .borg/ checkpoint files. This caused checkpoint files to silently appear untracked rather than staged, making it non-obvious that they were being ignored rather than simply not yet added.

## resolution

Removed the '.borg/' line from .gitignore and added correct scoped ignore entries ('.claude/' and 'templates/supabase/.borg/') for the directories that should actually be ignored. Checkpoint files then became properly trackable.
