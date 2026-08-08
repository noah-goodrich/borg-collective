---
id: obs-20260709-token-spend-junk-buckets
session_date: '2026-07-09'
project: cairn
tool: claude-code
tags:
- token-tracking
- project-attribution
- borg
- data-quality
category: domain_knowledge
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260709-1535-cairn
superseded_by: null
created_at: '2026-07-09 15:36:29.700296+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260709-token-spend-junk-buckets

## content

token_spend contains significant junk project buckets: '' (empty string) = 333 sessions, 'Desktop', '/'. This is a known borg spend attribution bug caused by Claude Desktop cwd slugging and git worktree slug resolution. call_log logs project '/' while token_spend logs '' or 'cairn' for the same sessions, so get_usage_stats cannot join them per project meaningfully.

## resolution

Fix the collector (token-cost/hooks/token-spend-log.sh in claude-plugins) to normalize project attribution, relabel the historical file, then re-run ingest-spend. Scheduled for next session.
