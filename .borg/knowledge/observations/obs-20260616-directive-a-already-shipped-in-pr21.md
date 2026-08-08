---
id: obs-20260616-directive-a-already-shipped-in-pr21
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- orchestrator-mode
- directive-a
- hooks
- session-separation
category: domain_knowledge
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.450466+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260616-directive-a-already-shipped-in-pr21

## content

Directive A (orchestrator-mode session separation) was found to be fully implemented inside PR #21, which had been sitting unmerged. The `_borg_session_mode()` helper, all three hook guards, and the full orchestrator overview renderer in borg-link-down.sh were all already present. The only missing pieces were bats test coverage (added in PR #33) and deployment via `borg setup`.

## resolution

Merged PR #21 (after rebase), added 4 bats tests in PR #33, ran `borg setup` to deploy live. Confirmed `diff ~/.claude/hooks/borg-link-down.sh repo` = IN SYNC. No new implementation was required.
