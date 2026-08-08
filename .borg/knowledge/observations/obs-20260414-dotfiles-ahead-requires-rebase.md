---
id: obs-20260414-dotfiles-ahead-requires-rebase
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- git
- dotfiles
- rebase
- push-rejected
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.225129+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260414-dotfiles-ahead-requires-rebase

## content

The dotfiles remote was 2 commits ahead of the local branch at push time (442d286..6104b1a). A plain git push was rejected. The local branch also had unstaged changes in zsh/.zshrc, requiring a stash → pull --rebase → stash pop → push sequence.

## resolution

git stash → git pull --rebase → git stash pop → git push. The round-trip succeeded with no conflicts. The .zshrc change was left intentionally uncommitted and noted as a follow-up task.
