---
id: 20260709-no-spend-record-flag
date: '2026-07-09'
project: borg-collective
domain: architecture
tags:
- token-spend
- cost-tracking
- claude-invocation
- ledger-pollution
alternatives: []
applies_to: []
confidence: 0.9
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260709-1659-borg-collective
created_at: '2026-07-09 17:01:17.383238+00:00'
updated_at: '2026-07-09 17:01:17.383239+00:00'
---

# 20260709-no-spend-record-flag

## decision

Set BORG_NO_SPEND_RECORD=1 on the claude invocation inside the poller to prevent zero-cost polling rows from polluting token-spend.jsonl.

## context

The poller was writing ~720 zero-cost rows/day into token-spend.jsonl (319 vs 267 real sessions in 11h, 54% of the ledger).

## reasoning

Zero-cost /usage polls are noise in the spend ledger and inflate session counts. The flag is scoped only to the poller's claude invocation, leaving all other recording intact.
