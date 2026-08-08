---
id: 20260731-ws2-deferred-pending-frequency-data
date: '2026-08-01'
project: cairn
domain: architecture
tags:
- backfill
- arbitrary-fact-persistence
- borg-collective
- instrumentation-first
alternatives: []
applies_to: []
confidence: 0.8
status: active
superseded_by: null
cost_to_produce: null
source_tool: cairn-backfill-commit
source_model: null
source_session: null
created_at: '2026-08-01 03:01:20.121484+00:00'
updated_at: '2026-08-01 03:01:20.121488+00:00'
---

# 20260731-ws2-deferred-pending-frequency-data

## decision

Deferred WS2 ('persist arbitrary fact' valve) until real frequency data from borg-collective recon justifies building it

## context

Issue #46 had a second workstream for a narrow explicit valve to persist arbitrary facts from recon fan-out. The team needed to decide whether to build it now.

## reasoning

Build cost is non-trivial and the actual frequency of facts that recon cannot persist is unknown. Instrumenting first (counter/log in _recon_persist_contradictions) lets real data drive the decision rather than speculative demand.
