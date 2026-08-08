---
id: obs-20260623-desktop-agent-mode-cwd-bogus-project
session_date: '2026-06-23'
project: cairn
tool: claude-code
tags:
- token-spend
- project-attribution
- claude-desktop
- agent-mode
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260623-0355-cairn
superseded_by: null
created_at: '2026-06-23 03:56:23.662148+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260623-desktop-agent-mode-cwd-bogus-project

## content

Claude Desktop agent-mode sessions set CWD to a path like `.../local-agent-mode-sessions/<uuid>/outputs`. The token-spend collector extracted the last path component (`outputs`) as the project name. Result: 21 sessions (~$12.9k spend) were all bucketed under a bogus 'outputs' project in `borg spend` reports.

## resolution

Add a case arm `*/local-agent-mode-sessions/*) PROJECT=claude-desktop ;;` in token-spend-log.sh before the default CWD-basename extraction. Relabel the 21 historical records after shipping.
