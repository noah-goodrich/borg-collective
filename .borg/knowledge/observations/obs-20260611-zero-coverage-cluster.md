---
id: obs-20260611-zero-coverage-cluster
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- test-coverage
- lib/tmux.zsh
- lib/coco.zsh
- lib/desktop.zsh
- lib/colors.zsh
- lib/borg-sync.zsh
- lib/borg-hooks.sh
category: domain_knowledge
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.529842+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-zero-coverage-cluster

## content

Zero-coverage cluster as of 2026-06-09: lib/tmux.zsh (8 fns), lib/coco.zsh (6), lib/desktop.zsh (3), lib/colors.zsh (2), lib/borg-sync.zsh (1). Additional uncovered functions in lib/borg-hooks.sh: _borg_sync_file, _borg_apply_claude_extensions, _borg_is_container, _borg_osa_notify, _borg_strip_ctl, _borg_resolve_proj_dir.

## resolution

Use this as the starting point for the next test-coverage sprint. tmux/desktop gaps likely require a mock display layer. borg-hooks gaps are more tractable and should be first targets.
