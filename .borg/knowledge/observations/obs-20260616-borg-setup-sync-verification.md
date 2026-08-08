---
id: obs-20260616-borg-setup-sync-verification
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- borg-setup
- deployment
- hooks
- diff-check
category: tool_behavior
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.450798+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260616-borg-setup-sync-verification

## content

`borg setup` deploys hook files from the repo into ~/.claude/hooks/. After running setup, diffing the deployed file against the repo source (`diff ~/.claude/hooks/borg-link-down.sh repo`) is a reliable way to confirm deployment succeeded and no stale version is live.

## resolution

Use `diff ~/.claude/hooks/<hook>.sh <repo-path>/hooks/<hook>.sh` as a post-deploy smoke check after any `borg setup` run that modifies hooks.
