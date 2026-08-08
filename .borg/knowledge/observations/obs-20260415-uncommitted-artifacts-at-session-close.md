---
id: obs-20260415-uncommitted-artifacts-at-session-close
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- git
- session-hygiene
- dotfiles
- directives
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.240399+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260415-uncommitted-artifacts-at-session-close

## content

Two artifacts were left uncommitted at session close: the portfolio pivot directive (`docs/plans/directives/2026-04-14-portfolio-mvp-pivot.md`, untracked) and a `.gitignore` update (unstaged). Because the session ended with a version bump and Homebrew formula update being the visible last commits, these changes are easy to overlook in a `git log` review.

## resolution

Establish a session-close checklist that includes `git status` before closing the editor. For plan/directive files especially, commit or stash before ending — they are the primary artifact of a planning session and have no other backup.
