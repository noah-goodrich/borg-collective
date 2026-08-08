---
id: 20260616-outbox-enqueue-first-ordering
date: '2026-06-16'
project: cairn
domain: architecture
tags:
- cairn
- outbox
- zero-loss
- atomicity
- fsync
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260616-0914-cairn
created_at: '2026-06-16 10:27:03.263380+00:00'
updated_at: '2026-06-16 10:27:03.263381+00:00'
---

# 20260616-outbox-enqueue-first-ordering

## decision

Outbox enqueue-first ordering: build entry in memory + compute body_sha256 → write pending/<id>.json.tmp → fsync → atomic os.replace into pending/<id>.json BEFORE any FS body write or cairn API call

## context

Designing the outbox for zero-data-loss guarantee; need to ensure no capture is silently dropped on crash

## reasoning

If the outbox entry is written last, a crash between the cairn call and the entry write loses the document with no record. Writing the entry first means any subsequent crash leaves a recoverable pending entry. The atomic rename ensures readers never see a partial write.
