---
id: obs-20260611-borg-setup-rerun-required-for-new-hooks
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- borg
- hooks
- claude-code
- setup
- activation
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.438684+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-borg-setup-rerun-required-for-new-hooks

## content

Merging a PR that adds a new PreToolUse hook to borg-collective does NOT automatically activate that hook in the local Claude Code settings. `borg setup` must be re-run after merge to register the new hook in ~/.claude/settings.json. This is the same activation pattern as Directive A.

## resolution

After PR #21 (borg-plan-promote) is merged, explicitly run `borg setup` to install the new hook. Document this as a required post-merge step in the PR description.
