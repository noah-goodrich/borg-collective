---
id: 20260611-dangling-symlink-removal
date: '2026-06-11'
project: borg-collective
domain: code-quality
tags:
- borg.zsh
- symlink
- CLAUDE.md
- setup
alternatives: []
applies_to: []
confidence: 0.9
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 22:41:19.302612+00:00'
updated_at: '2026-06-11 22:41:19.302613+00:00'
---

# 20260611-dangling-symlink-removal

## decision

Explicitly remove dangling symlinks before cp in _borg_merge_claude_md

## context

cp fails silently or errors when the destination path is a dangling symlink (target deleted), leaving CLAUDE.md missing

## reasoning

A prior borg setup may have left CLAUDE.md as a symlink to a path that no longer exists. cp does not overwrite a dangling symlink with a real file — it either errors or follows the broken link. Removing it first ensures cp creates a proper file.
