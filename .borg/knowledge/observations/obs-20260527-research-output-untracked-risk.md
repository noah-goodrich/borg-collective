---
id: obs-20260527-research-output-untracked-risk
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- research
- untracked-files
- positioning-refresh
- git-workflow
category: gotcha
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.447959+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260527-research-output-untracked-risk

## content

The positioning-refresh research outputs (`docs/research/2026-05-22-positioning-refresh/`) were drafted and sitting in the worktree as untracked files — not on any branch's commit history. They would be invisible to `git status` on another branch and could be accidentally overwritten or lost if the worktree is cleaned.

## resolution

Captured in the research-branch-split handoff doc with explicit routing instructions. General principle: untracked research outputs should be committed to a holding branch promptly, even if only as a WIP commit, to protect them from accidental loss.
