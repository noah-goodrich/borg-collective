---
id: obs-20260616-borg-watch-agents-jsonl-tail
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- borg-watch
- agents-jsonl
- nanoprobe
- display
category: domain_knowledge
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.469021+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260616-borg-watch-agents-jsonl-tail

## content

borg watch displays the last 5 nanoprobe entries from agents.jsonl with ⚠/✓ evidence badges. Because agents.jsonl is append-only, 'tail -n 5' is the correct and efficient read pattern — no need to parse the full file on each refresh cycle.

## resolution

For live-refresh displays of append-only JSONL logs, use tail -n N | jq to minimize per-cycle work. Avoid loading the full file.
