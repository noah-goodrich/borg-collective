---
id: codex-contradiction-query-fixture-verification
project: cairn
domain: testing
tags:
- codex
- belief-store
- contradiction-detection
- fixtures
- tdd
preconditions: []
steps:
- Seed a conflicting belief pair (cosine similarity above the configured contradiction
  threshold, opposite claims)
- Seed a reinforcing belief pair (high similarity, consistent claims — should NOT
  be flagged)
- Run the contradiction query against the seeded data
- Assert the conflicting pair appears in results
- Assert the reinforcing pair does NOT appear in results
- Assert the threshold is read from config (not hardcoded) by varying the config value
  and re-running
pitfalls:
- Reinforcing pairs with very high similarity can be mistaken for contradictions if
  the query uses only vector distance without a semantic sign check — ensure the query
  or post-filter distinguishes similar-but-consistent from similar-but-conflicting
- Threshold must be sourced from config, not hardcoded in the query, or calibration
  changes require a code deploy
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: null
superseded_by: null
created_at: '2026-07-24 03:54:03.157037+00:00'
updated_at: '2026-07-24 03:55:23.997706+00:00'
---

# codex-contradiction-query-fixture-verification

## description

Fixture-verify the contradiction detection query by seeding a known conflicting pair and a known reinforcing pair, then asserting the threshold logic fires correctly for each.
