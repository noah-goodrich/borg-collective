---
id: obs-20260513-hooks-not-live-until-setup
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- borg-collective
- hooks
- deployment
- borg-setup
- installation
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.428885+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260513-hooks-not-live-until-setup

## content

Merging new hook code to main does NOT activate the new hooks. The running session still uses previously-installed hooks copied to ~/.claude/hooks/. New hook behavior is only active after explicitly running 'borg setup', which copies the updated scripts into place.

## resolution

Always run 'borg setup' after merging hook changes to main before expecting new behavior in any session. Add this to the post-merge checklist. Verification: start a new session and confirm the orchestrator overview block renders at ~/dev.
