---
id: cairn-documents-scd-type1-captured-at-guard-2026-06-09
date: '2026-06-10'
project: cairn
domain: db
tags:
- postgres
- documents
- upsert
- outbox
- zero-loss
alternatives: []
applies_to: []
confidence: 0.95
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260610-1630-cairn
created_at: '2026-06-10 16:50:37.416901+00:00'
updated_at: '2026-06-10 16:50:37.416902+00:00'
---

# cairn-documents-scd-type1-captured-at-guard-2026-06-09

## decision

The documents table is SCD Type 1 (current state only) with an ON CONFLICT (id) DO UPDATE ... WHERE EXCLUDED.captured_at >= documents.captured_at guard. Append-only audit is the outbox done/ archive, not a second DB table.

## context

Designing the general document store for v0.2. Out-of-order drain replay is a real risk when entries are batched.

## reasoning

A second audit table adds schema complexity and write amplification. The outbox done/ directory is already an append-only JSONL archive by construction — no duplication needed.
