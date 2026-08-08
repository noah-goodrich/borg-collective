---
id: obs-20260507-subagent-stop-hook-unexercised
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- SubagentStop
- hook
- nanoprobe
- JSONL
- pipeline
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.349853+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260507-subagent-stop-hook-unexercised

## content

The SubagentStop → JSONL pipeline was fully implemented and registered in both Claude Code and CoCo settings, but was NOT exercised by a real Agent tool spawn during this session. The hook may fire correctly, or the payload schema may differ from what `hooks/borg-nanoprobe-log.sh` expects — this is unknown until first live spawn.

## resolution

First action next session: spawn a trivial nanoprobe via Agent tool, then run `borg nanoprobes` to confirm a JSONL entry landed in `~/.config/borg/agents.jsonl`. Treat as broken until confirmed.
