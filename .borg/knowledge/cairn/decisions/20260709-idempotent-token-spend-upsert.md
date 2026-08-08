---
id: 20260709-idempotent-token-spend-upsert
date: '2026-07-09'
project: cairn
domain: architecture
tags:
- idempotency
- cli
- token-tracking
- data-ingestion
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260709-1535-cairn
created_at: '2026-07-09 15:36:29.692477+00:00'
updated_at: '2026-07-09 15:36:29.692477+00:00'
---

# 20260709-idempotent-token-spend-upsert

## decision

ingest-spend uses idempotent upsert on (session_id, ts) so re-running against the same JSONL file is safe

## context

token-spend.jsonl grows continuously; operators need to be able to re-run ingest without duplicating rows

## reasoning

The natural key (session_id, ts) is stable per Claude session entry. Upsert is simpler than tracking a high-water mark and more robust against partial runs.
