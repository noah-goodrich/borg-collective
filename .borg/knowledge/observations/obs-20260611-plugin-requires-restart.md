---
id: obs-20260611-plugin-requires-restart
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- claude-code
- plugins
- hooks
- restart
- activation
category: tool_behavior
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.541440+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-plugin-requires-restart

## content

Installing or updating a Claude Code plugin (including `borg-collective@noah-local`) does not activate the new hooks in the current session. Hooks are loaded at session start only.

## resolution

Always restart Claude Code after plugin install/update to activate changes. This is a required step in any plugin deployment checklist.
