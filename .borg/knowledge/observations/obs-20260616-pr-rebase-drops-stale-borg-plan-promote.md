---
id: obs-20260616-pr-rebase-drops-stale-borg-plan-promote
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- git
- rebase
- stale-commits
- pr-hygiene
category: pattern_discovered
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.450138+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260616-pr-rebase-drops-stale-borg-plan-promote

## content

PR #21 (orchestrator-mode session separation) contained 3 stale borg-plan-promote commits that were no longer relevant. PRs #22 and #23 each contained 8–10 stale commits. These had accumulated because the branches were created early and then left open while related work landed on main via other PRs. Interactive rebase before merge is the correct remedy.

## resolution

Interactively rebased each branch, dropped stale commits, verified tests, then merged. All three PRs landed cleanly. Establish a norm: before opening a PR for long-lived branches, audit commits with `git log --oneline main..HEAD` and drop anything superseded.
