---
id: obs-20260609-zero-coverage-cluster-by-file
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- coverage
- zsh
- testing
- lib/tmux.zsh
- lib/coco.zsh
- lib/desktop.zsh
category: domain_knowledge
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.513777+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260609-zero-coverage-cluster-by-file

## content

The zero-coverage cluster in borg-collective is concentrated in whole files, not scattered functions: lib/tmux.zsh (8 fns), lib/coco.zsh (6), lib/desktop.zsh (3), lib/colors.zsh (2), lib/borg-sync.zsh (1). Additionally, six specific functions in lib/borg-hooks.sh have no test coverage: _borg_sync_file, _borg_apply_claude_extensions, _borg_is_container, _borg_osa_notify, _borg_strip_ctl, _borg_resolve_proj_dir.

## resolution

File targeted test directives for each zero-coverage file before writing new features in those modules. The hooks.sh gaps are higher priority because those functions run on every session boundary.
