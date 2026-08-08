---
id: service-layer-routing-for-bulk-writes
project: cairn
domain: write-path
tags:
- batch
- service-layer
- embedding
- backfill
- cli
preconditions: []
steps:
- Identify the correct service batch method (e.g., `service.record_batch`)
- Group candidates by their natural batch boundary (file, session, etc.)
- Call the batch method once per group, passing all items
- Use the returned results to map back to source items for logging/counting (zip with
  items, preserving order)
- Attach a `source_tool` tag to distinguish programmatic writes from interactive ones
- Delete any post-step workarounds (e.g., manual re-embed) that the service layer
  now handles
pitfalls:
- '`zip(items, result[''results''])` assumes `record_batch` preserves item order —
  this is currently true and test-covered, but would silently miscount if the service
  ever reorders results'
- Verify that the service layer does NOT run contradiction detection inline before
  assuming rerouting adds query overhead — in cairn, contradiction detection is a
  decoupled on-demand pass, not per-write
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: null
superseded_by: null
created_at: '2026-07-30 23:23:43.168595+00:00'
updated_at: '2026-07-30 23:23:43.168597+00:00'
---

# service-layer-routing-for-bulk-writes

## description

When adding a new bulk-write CLI path, fan candidates into the existing service batch endpoint rather than writing directly to DB. One batch per logical unit (e.g., per YAML file).
