---
id: obs-20260414-unstaged-changes-blocked-dotfiles-push
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- git
- dotfiles
- stash
- workflow
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 20:39:24.979810+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260414-unstaged-changes-blocked-dotfiles-push

## content

At push time, dotfiles had unstaged changes in zsh/.zshrc unrelated to the current feature. Combined with the remote being 2 commits ahead, a naive push would have either failed or required a merge commit. The .zshrc change was intentionally left uncommitted after stash pop, making it invisible to future sessions unless explicitly tracked.

## resolution

Used git stash → pull --rebase → stash pop → push. The deferred .zshrc commit was logged as an explicit next-step. Future sessions should check 'git stash list' and 'git status' in dotfiles at session start before making new changes.
