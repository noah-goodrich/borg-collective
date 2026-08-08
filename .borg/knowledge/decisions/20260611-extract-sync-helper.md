---
id: 20260611-extract-sync-helper
date: '2026-06-11'
project: borg-collective
domain: code-quality
tags:
- DRY
- shell
- helper
- lib
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 22:41:19.215553+00:00'
updated_at: '2026-06-11 22:41:19.215553+00:00'
---

# 20260611-extract-sync-helper

## decision

Extract `_borg_sync_file` into shared lib files (`lib/borg-hooks.sh`, `lib/borg-sync.zsh`) rather than duplicating copy logic in `borg.zsh` and `drone.zsh`

## context

Both borg.zsh and drone.zsh needed the same mtime-copy logic for CLAUDE.md syncing.


## reasoning

Single source of truth prevents the two entry-points from drifting. Lib files are already sourced by both, so no new loading mechanism was required.

