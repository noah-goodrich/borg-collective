---
id: obs-20260617-zero-coverage-clusters
session_date: '2026-06-17'
project: borg-collective
tool: claude-code
tags:
- coverage
- testing
- zsh
- lib/tmux.zsh
- lib/coco.zsh
- lib/desktop.zsh
category: domain_knowledge
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-17 18:03:01.148821+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260617-zero-coverage-clusters

## content

Static analysis identified ~20 zero-coverage functions concentrated in five files: lib/tmux.zsh (8 fns), lib/coco.zsh (6), lib/desktop.zsh (3), lib/colors.zsh (2), lib/borg-sync.zsh (1). Additionally, six functions in lib/borg-hooks.sh are untested: _borg_sync_file, _borg_apply_claude_extensions, _borg_is_container, _borg_osa_notify, _borg_strip_ctl, _borg_resolve_proj_dir.

## resolution

Prioritize test authoring for lib/tmux.zsh and lib/coco.zsh first (highest function count, likely highest risk). lib/borg-hooks.sh gaps include the notify path now partially addressed by inlining _borg_osa_notify into hooks/notify.sh.
