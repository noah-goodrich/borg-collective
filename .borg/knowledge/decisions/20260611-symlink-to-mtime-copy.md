---
id: 20260611-symlink-to-mtime-copy
date: '2026-06-11'
project: borg-collective
domain: infrastructure
tags:
- claude.md
- file-sync
- symlinks
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
created_at: '2026-06-11 20:39:24.962993+00:00'
updated_at: '2026-06-11 20:39:24.962996+00:00'
---

# 20260611-symlink-to-mtime-copy

## decision

Replace CLAUDE.md symlink strategy with mtime-based file copy via shared `_borg_sync_file` helper

## context

CLAUDE.md needed to be present in project directories for Claude to pick up instructions. Symlinks were the initial approach.

## reasoning

Symlinks break inside containers (host paths don't resolve), and symlink-to-file migration edge cases caused silent failures. An mtime-based copy heals itself on every session start and `borg setup` run without requiring python3 or special tooling.
