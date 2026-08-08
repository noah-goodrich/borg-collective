---
id: obs-20260731-record-batch-order-assumption
session_date: '2026-08-01'
project: cairn
tool: claude-code
tags:
- record_batch
- ordering
- silent-failure
- backfill
category: gotcha
files_involved: []
confidence: 0.8
source_model: null
source_session: null
superseded_by: null
created_at: '2026-08-01 03:01:20.258155+00:00'
updated_at: '2026-08-01 03:01:20.258156+00:00'
---

# obs-20260731-record-batch-order-assumption

## content

_commit_candidate_file uses zip(items, result['results']) which silently miscounts if record_batch ever reorders results relative to inputs. Currently documented and test-covered under the assumption that order is preserved, but there is no enforcement of that contract.

## resolution

Noted as a carry-forward nit. If record_batch ever changes to reorder results (e.g., for batching optimization), the commit step would attribute embeddings/results to the wrong candidate rows without raising an error. Future hardening: add positional IDs or keyed results to the record_batch response.
