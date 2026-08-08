---
id: obs-20260623-marketplace-mirror-drift
session_date: '2026-06-23'
project: cairn
tool: claude-code
tags:
- claude-plugins
- borg-collective
- borg-setup
- marketplace-mirror
category: tool_behavior
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260623-0355-cairn
superseded_by: null
created_at: '2026-06-23 03:56:23.664001+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260623-marketplace-mirror-drift

## content

`borg setup` rebuilds the marketplace mirror of borg-collective into claude-plugins/borg-collective/. After PRs #54/#55 merged, the claude-plugins main branch shows unstaged modifications to borg-collective/agents/borg-nanoprobe.md and borg-collective/hooks/borg-link-up.sh. This is expected drift — borg setup overwrites the mirror but does not auto-commit.

## resolution

Periodic housekeeping commit to claude-plugins main after any borg-collective release. Low priority but accumulates if ignored across multiple releases.
