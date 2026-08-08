---
id: gated-ship-sequence
project: cairn
domain: code-quality
tags:
- release-process
- testing
- verification
- borg
preconditions: []
steps:
- Run `/simplify` on all changed files — confirm no edits required
- Run Collective Review — confirm ship verdict
- Run `borg-verify` — check that new real-DB tests appear in output as PASS, not as
  skipped
- Merge only after all three gates pass
pitfalls:
- Real-DB tests can be silently skipped if DB fixtures aren't available — borg-verify
  catches this; a green pytest run alone does not
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: null
superseded_by: null
created_at: '2026-07-30 23:23:43.191362+00:00'
updated_at: '2026-07-30 23:23:43.191365+00:00'
---

# gated-ship-sequence

## description

Before merging any cairn PR that adds new DB-touching code: run /simplify, Collective Review, then borg-verify to confirm real-DB tests actually execute (not skipped).
