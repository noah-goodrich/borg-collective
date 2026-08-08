---
id: obs-20260616-pr-commit-overlap-after-split
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- git
- cherry-pick
- pr-split
- duplicate-commits
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.439963+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260616-pr-commit-overlap-after-split

## content

PR #21 was originally created before PR #29 and contained commits for two concerns: orchestrator-mode (its stated purpose) and borg-plan-promote (which later landed via PR #29). After PR #29 merged, PR #21 still showed those 3 promote commits in its diff, making a straight merge or rebase produce duplicates/conflicts.

## resolution

Cherry-picked only the 5 orchestrator-mode commits onto a fresh branch, force-pushed, retitled the PR, then merged. The key signal was that the commit SHAs for the promote work were already on main — cherry-pick skips already-present content cleanly.
