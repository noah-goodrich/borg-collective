---
id: obs-20260709-ledger-pollution-from-poller
session_date: '2026-07-09'
project: borg-collective
tool: claude-code
tags:
- token-spend
- ledger
- claude-invocation
- session-count
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260709-1659-borg-collective
superseded_by: null
created_at: '2026-07-09 17:01:17.389150+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260709-ledger-pollution-from-poller

## content

Any tool that invokes claude as a subprocess will write to token-spend.jsonl by default, even for zero-cost calls. The /usage poller generated 319 ledger rows vs 267 real sessions in 11h — 54% of the ledger was noise, inflating session counts.

## resolution

Set BORG_NO_SPEND_RECORD=1 on any claude invocation that is infrastructure/tooling rather than a real user session. Scope the flag narrowly to that invocation only.
