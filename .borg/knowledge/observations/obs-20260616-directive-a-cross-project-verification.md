---
id: obs-20260616-directive-a-cross-project-verification
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- directive-a
- borg-collective
- session-start
- multi-project
- orchestration
category: pattern_discovered
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.389807+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260616-directive-a-cross-project-verification

## content

Directive A (cross-project overview on SessionStart) was verified live: the orchestrator session opened with a multi-project status view rather than a single project's checkpoint. This confirms the Directive A activation pattern (borg setup → installs hook into ~/.claude/settings.json) works end-to-end.

## resolution

P0 #1 from prior session closed. The same activation pattern applies to PR #21's new PreToolUse hook — `borg setup` must be re-run after merging to install it.
