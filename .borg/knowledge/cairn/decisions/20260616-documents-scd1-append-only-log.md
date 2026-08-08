---
id: 20260616-documents-scd1-append-only-log
date: '2026-06-16'
project: cairn
domain: architecture
tags:
- cairn
- documents
- scd
- zero-loss
- outbox
- git
- schema
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260616-0914-cairn
created_at: '2026-06-16 10:27:03.262790+00:00'
updated_at: '2026-06-16 10:27:03.262791+00:00'
---

# 20260616-documents-scd1-append-only-log

## decision

documents table is SCD Type 1 (upsert on composite PK) + append-only audit via git (for FS-backed docs) or outbox done/ archive (for the rest) — NOT a second DB table for history

## context

Designing the documents storage model with zero-data-loss requirement and Stillpoint Labs standards compliance

## reasoning

A second history table adds complexity and a failure mode (history insert can fail independently). Git provides durable, diffable history for FS-backed docs for free. The outbox done/ directory provides the audit trail for non-FS docs without an extra DB dependency. Keeps the schema minimal.
