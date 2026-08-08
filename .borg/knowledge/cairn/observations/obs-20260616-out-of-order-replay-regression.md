---
id: obs-20260616-out-of-order-replay-regression
session_date: '2026-06-16'
project: cairn
tool: claude-code
tags:
- replay
- ordering
- postgres
- upsert
- outbox
- drain
- data-loss
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260616-0914-cairn
superseded_by: null
created_at: '2026-06-16 10:27:03.293415+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260616-out-of-order-replay-regression

## content

If drain replays outbox entries out of captured_at order (possible after crash+restart with partial drain), a naive ON CONFLICT DO UPDATE will overwrite a newer document body with an older one. The DB row silently regresses to stale content with no error — this is a data_loss class bug that passes all basic tests.

## resolution

Drain replay MUST use ON CONFLICT (id) DO UPDATE ... WHERE EXCLUDED.captured_at >= documents.captured_at. The golden-manifest zero-loss oracle must assert the live DB row equals the max(captured_at) entry across done/ ∪ pending/ to catch silent regressions.
