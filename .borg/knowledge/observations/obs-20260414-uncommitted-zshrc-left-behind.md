---
id: obs-20260414-uncommitted-zshrc-left-behind
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- git
- dotfiles
- zshrc
- unstaged-changes
- follow-up
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.225520+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260414-uncommitted-zshrc-left-behind

## content

zsh/.zshrc had unstaged changes in the dotfiles repo at the end of the session. The changes were stashed to allow the push but were intentionally not committed. If the next session modifies dotfiles without first reviewing and committing this change, it risks being lost or creating a conflict.

## resolution

Explicitly tracked as a next-step: review the .zshrc diff and commit it before the next session touches dotfiles. Running git stash list or git diff at session start on the dotfiles repo is a safe habit.
