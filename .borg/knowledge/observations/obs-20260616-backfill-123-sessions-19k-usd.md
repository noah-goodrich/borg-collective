---
id: obs-20260616-backfill-123-sessions-19k-usd
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- token-spend
- backfill
- cost
- historical
- api-equivalent
category: domain_knowledge
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.529191+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260616-backfill-123-sessions-19k-usd

## content

Backfilling 123 historical claude-code sessions yielded $19,485 API-equivalent total spend. This is queryable by project/date via `jq` against `~/.claude/token-spend.jsonl`. The figure is 'API-equivalent' — actual billing may differ based on subscription vs. API pricing.

## resolution

Ledger is now established. Re-run `backfill-spend.sh` each session where the collector wasn't active to keep it current.
