---
id: directive-orphan-prevention-workflow
project: borg-collective
domain: documentation
tags:
- directives
- orphan-prevention
- workflow
- borg
- back-links
preconditions: []
steps:
- 'When writing a new directive during execution of a parent plan, add `*Parent plan:
  <parent-slug>*` as an italic metadata line near the top of the directive file'
- 'When assimilating a plan (`/borg-assimilate`), run a child-check: scan directives
  dir for any that reference this plan''s slug as parent but lack assimilation status'
- Surface unassimilated child directives in `borg-link-down` output so they're visible
  at session start
- Add a post-commit nudge in `borg-link-up` if unassimilated directives exist for
  the current project
pitfalls:
- If back-links are added retroactively (after orphaning), note the orphan event and
  date in the back-link line for auditability
- Orphaned directives may be actively harmful, not merely inert — audit whether the
  feature is live in production before deciding to sever vs. ship
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.239836+00:00'
updated_at: '2026-06-16 10:27:02.239837+00:00'
---

# directive-orphan-prevention-workflow

## description

Pattern for preventing directives spawned during plan execution from becoming orphaned (untracked, unshipped, stale)
