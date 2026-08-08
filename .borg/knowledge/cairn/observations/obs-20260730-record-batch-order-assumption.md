---
id: obs-20260730-record-batch-order-assumption
session_date: '2026-07-30'
project: cairn
tool: claude-code
tags:
- record_batch
- ordering
- zip
- silent-failure
category: gotcha
files_involved: []
confidence: 0.7
source_model: null
source_session: null
superseded_by: null
created_at: '2026-07-30 23:23:43.265954+00:00'
updated_at: '2026-07-30 23:23:43.265957+00:00'
---

# obs-20260730-record-batch-order-assumption

## content

The pattern `zip(items, result['results'])` in `_commit_candidate_file` silently miscounts if `record_batch` ever returns results in a different order than input items. This is currently safe and test-covered, but is a latent risk if the batch endpoint changes.

## resolution

Document the ordering assumption in the code. If `record_batch` is ever refactored, check this call site. A more robust approach would be to have the service return results keyed by item ID rather than positionally.
