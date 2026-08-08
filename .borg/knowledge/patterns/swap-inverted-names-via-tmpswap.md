---
id: swap-inverted-names-via-tmpswap
project: borg-collective
domain: infrastructure
tags:
- git
- rename
- naming
- file-management
preconditions: []
steps:
- Rename A to A.tmpswap
- Rename B to A (original A's target name)
- Rename A.tmpswap to B (original B's target name)
- 'Update all internal references (name: fields, comments, hook registrations) in
  both files to match their new filenames'
- Update all external references in one sweep (settings.json, install.sh, docs, tests)
  before staging
- Stage everything as a single commit to avoid git history showing the intermediate
  .tmpswap state
pitfalls:
- If you commit after step 1-3 without updating references, the intermediate state
  is recorded in history as noise — do the full reference sweep before any commit
- Live environment files (e.g. ~/.claude/settings.json) must be updated in addition
  to the repo canonical files; easy to miss one
- Tests that assert specific hook filenames will fail immediately after the rename
  if not updated atomically
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.210950+00:00'
updated_at: '2026-06-16 10:27:02.210951+00:00'
---

# swap-inverted-names-via-tmpswap

## description

Safely swap two filenames that would collide if renamed directly (A→B, B→A) by using intermediate .tmpswap names to avoid filesystem or git conflicts.
