---
id: 20260623-spend-attribution-case-arm-pattern
date: '2026-06-23'
project: cairn
domain: infrastructure
tags:
- token-spend
- project-attribution
- shell
- claude-plugins
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260623-0355-cairn
created_at: '2026-06-23 03:56:23.658643+00:00'
updated_at: '2026-06-23 03:56:23.658646+00:00'
---

# 20260623-spend-attribution-case-arm-pattern

## decision

Use a `case` statement in token-spend-log.sh to classify CWD paths into canonical project names before writing to token-spend.jsonl

## context

Two attribution bugs surfaced via live data: Claude Desktop agent-mode sessions (cwd under .../local-agent-mode-sessions/.../outputs) and git-worktree sessions (.claude/worktrees/<slug>) were both producing misleading project names in spend reports

## reasoning

A case statement at collection time is the lowest-friction fix — data is correct at write time, no post-processing required, and the hook already had structure to add arms to
