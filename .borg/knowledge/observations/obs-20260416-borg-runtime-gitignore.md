---
id: obs-20260416-borg-runtime-gitignore
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- borg-collective
- gitignore
- runtime-state
- local-tooling
category: pattern_discovered
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 20:39:25.026886+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260416-borg-runtime-gitignore

## content

The `.borg/` directory holds local borg runtime state and must be excluded from version control. It was not in `.gitignore` prior to this session; this was caught and fixed here. Any borg-collective repo clone that predates this commit will produce untracked `.borg/` noise in `git status`.

## resolution

`.gitignore` entry added. Existing clones with a stale `.borg/` should run `git rm -r --cached .borg/` if the directory was ever accidentally staged.
