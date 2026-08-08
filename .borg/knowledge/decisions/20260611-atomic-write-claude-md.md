---
id: 20260611-atomic-write-claude-md
date: '2026-06-11'
project: borg-collective
domain: code-quality
tags:
- borg.zsh
- atomic-write
- truncation
- claude-md
alternatives: []
applies_to: []
confidence: 0.9
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 20:39:25.099106+00:00'
updated_at: '2026-06-11 20:39:25.099106+00:00'
---

# 20260611-atomic-write-claude-md

## decision

Use atomic write pattern (write to temp file, then mv) when generating CLAUDE.md in _borg_merge_claude_md

## context

Interrupted setup operations were leaving CLAUDE.md truncated — a partial write is worse than no write

## reasoning

mv on the same filesystem is atomic at the OS level; a truncated CLAUDE.md causes silent, confusing failures downstream. The temp-then-mv pattern is the standard fix.
