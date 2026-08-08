---
id: 20260611-mtime-copy-over-symlink
date: '2026-06-11'
project: borg-collective
domain: infrastructure
tags:
- CLAUDE.md
- symlink
- file-sync
- shell
- devcontainer
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 22:41:19.214188+00:00'
updated_at: '2026-06-11 22:41:19.214190+00:00'
---

# 20260611-mtime-copy-over-symlink

## decision

Replace CLAUDE.md symlink strategy with mtime-based file copy via shared `_borg_sync_file` helper

## context

CLAUDE.md was previously symlinked into projects, but symlinks inside containers can break when host paths don't resolve, and the strategy didn't self-heal on drift.


## reasoning

mtime-based copy is container-safe (no host-path dependency), handles the symlink-to-file migration case for existing repos, requires no python3, and heals automatically on every `borg setup` run and session start.

