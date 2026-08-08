---
id: borg-assimilate-review-loop
project: borg-collective
domain: code-quality
tags:
- borg-collective
- assimilate
- simplify
- review-workflow
preconditions: []
steps:
- Run `/simplify` on all new/modified SQL migration files — fixes comments, dedup
  descriptions, flags false positives
- Run `/borg-assimilate` for Collective-level review of the full directive scope
- 'Triage findings: action real issues (e.g. missing cleanup migration, directive
  gaps), mark false positives explicitly'
- Re-run `/borg-assimilate` if significant changes were made to confirm pass
- Move directive file from `docs/plans/directives/` to `docs/plans/assimilated/`
pitfalls:
- /simplify findings on already-applied migrations cannot be fixed in-place without
  creating a new migration — treat as documentation-only fixes or defer
- False positives from /simplify are common on SQL with intentional patterns (e.g.
  NOT EXISTS dedup logic); document the intent in comments rather than changing the
  logic
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.323238+00:00'
updated_at: '2026-06-16 10:27:02.323239+00:00'
---

# borg-assimilate-review-loop

## description

End-of-directive review workflow: run /simplify then /borg-assimilate, action the findings, then archive
