---
id: 20260730-defer-arbitrary-fact-valve
date: '2026-07-30'
project: cairn
domain: architecture
tags:
- borg-collective
- recon
- scope-control
- instrumentation-first
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: cairn-backfill-commit
source_model: null
source_session: null
created_at: '2026-07-30 23:23:43.112448+00:00'
updated_at: '2026-07-30 23:23:43.112454+00:00'
---

# 20260730-defer-arbitrary-fact-valve

## decision

Defer WS2 ('persist arbitrary fact' valve) until real frequency data justifies it; instrument borg-collective recon first to measure the actual gap

## context

Two anecdotes suggested a need for a valve to persist non-contradiction facts from borg-collective recon into cairn. The question was whether to build it now.

## reasoning

Two anecdotes are insufficient signal. The correct next step is to add a counter/log in `_recon_persist_contradictions` for facts it could NOT persist, then let real frequency data justify the engineering investment.
