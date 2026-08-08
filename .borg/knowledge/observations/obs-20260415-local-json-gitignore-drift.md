---
id: obs-20260415-local-json-gitignore-drift
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- git
- gitignore
- generated-files
- settings-management
category: gotcha
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.232796+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260415-local-json-gitignore-drift

## content

.gitignore had unstaged changes at session end. The likely cause is that borg setup generates ~/.config/borg/claude-settings.local.json on first run, and the corresponding ignore pattern was added during the session but not staged. If left uncommitted, the generated file could accidentally be tracked on another machine.

## resolution

Review .gitignore diff to confirm it excludes *.local.json or the specific generated path, then stage and commit alongside the directive.
