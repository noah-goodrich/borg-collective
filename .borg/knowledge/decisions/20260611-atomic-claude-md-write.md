---
id: 20260611-atomic-claude-md-write
date: '2026-06-11'
project: borg-collective
domain: code-quality
tags:
- borg.zsh
- atomic-write
- truncation
- CLAUDE.md
alternatives: []
applies_to: []
confidence: 0.9
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 22:41:19.302211+00:00'
updated_at: '2026-06-11 22:41:19.302212+00:00'
---

# 20260611-atomic-claude-md-write

## decision

Use atomic write pattern (write to temp file, then mv) for _borg_merge_claude_md instead of direct file write

## context

CLAUDE.md was being truncated when setup was interrupted mid-write

## reasoning

mv on the same filesystem is atomic at the OS level; a partial write followed by interruption leaves the destination file truncated. Atomic write ensures the file is either fully written or unchanged.
