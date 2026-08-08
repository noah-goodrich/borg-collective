---
id: obs-20260513-installed-hooks-lag
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- borg-collective
- hooks
- deployment
- setup
- claude-code
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.377868+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260513-installed-hooks-lag

## content

Shipping new hook scripts to the repo does NOT activate them. Claude Code reads hooks from ~/.claude/hooks/ (the installed location), not from the repo working tree. A borg setup re-run is required to copy updated hooks into the active location. The current session runs on the pre-update hooks for its entire duration even after the branch merges.

## resolution

After any merge that touches hook scripts, run 'borg setup' before starting the next session. Verify by checking that orchestrator sessions at ~/dev render the overview block. Document this in the post-merge checklist.
