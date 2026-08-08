---
id: obs-20260423-tmux-conf-edit-not-verified
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- tmux
- dotfiles
- symlink
- git-diff
- unverified-edit
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 20:39:25.125241+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260423-tmux-conf-edit-not-verified

## content

The assistant reported adding tmux layout hotkeys (`bind = select-layout even-horizontal`, `bind _ select-layout even-vertical`) and removing a 70/30 3-pane auto-resize hook from `dotfiles/tmux/tmux.conf`. However, because the file is symlinked and not git-tracked in the normal way, these changes did NOT appear in `git diff`. The session ended without confirming the edits actually landed on disk.

## resolution

Always verify symlinked dotfile edits with a direct `grep` or `cat` — do not trust git diff for symlinked files. Verification command: `grep -n 'even-horizontal\|even-vertical' ~/dev/borg-collective/dotfiles/tmux/tmux.conf`. If empty, the edits were described but not written and must be re-applied manually.
