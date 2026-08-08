---
id: 20260617-cairn-extraction-max-tokens-increase
date: '2026-06-17'
project: borg-collective
domain: code-quality
tags:
- cairn
- anthropic
- extraction
- llm
- streaming
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260616-0347-orchestrator
created_at: '2026-06-17 18:01:10.020919+00:00'
updated_at: '2026-06-17 18:01:10.020919+00:00'
---

# 20260617-cairn-extraction-max-tokens-increase

## decision

Increase `max_tokens` from 4096 to 16384 in cairn extraction calls, add streaming, and implement 4-retry logic.

## context

Backfill extraction was failing with OOM/disconnect errors on large files.

## reasoning

Large knowledge-dense files require more output tokens than 4096 allows. Streaming prevents timeout disconnects. Retries handle transient API failures.
