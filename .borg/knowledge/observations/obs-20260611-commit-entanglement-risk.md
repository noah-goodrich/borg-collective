---
id: obs-20260611-commit-entanglement-risk
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- git
- drone
- tmux
- commits
- separation-of-concerns
category: gotcha
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.328030+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-commit-entanglement-risk

## content

drone.zsh accumulated two logically independent changes in the same working-tree file: the cmd_scaffold preflight-ordering fix (workspace collision) and the create_2pane_window side-by-side layout change (tmux work). These belong in separate commits but cannot be split without interactive staging (git add -p). Letting unrelated changes accumulate in the same file across sessions makes clean commit separation harder.

## resolution

Planned as Commit A: drone.zsh + templates/supabase/devcontainer.json (workspace/tmux defaults). Commit B: lifecycle redesign files. Use git add -p to split drone.zsh between the two commits.
