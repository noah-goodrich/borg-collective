---
id: obs-20260423-tmux-conf-symlink-git-invisibility
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- tmux
- dotfiles
- symlink
- git
- unverified-edits
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.322324+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260423-tmux-conf-symlink-git-invisibility

## content

The AI assistant reported making edits to `dotfiles/tmux/tmux.conf` (adding layout keybinds, removing a resize hook), but because the file is symlinked and potentially not git-tracked in the normal sense, the changes did not appear in `git diff`. The session ended without confirmation that the edits actually landed on disk.

## resolution

After any session where an AI assistant edits a symlinked or non-tracked dotfile, verify with a direct `grep` before trusting the changes exist: `grep -n 'even-horizontal\|even-vertical' ~/dev/borg-collective/dotfiles/tmux/tmux.conf`. If empty, the edits were described but not written and must be re-applied manually.
