---
id: assimilate-plan-closeout
project: cairn
domain: project-management
tags:
- assimilate
- documentation
- plan
- closeout
- gitignore
preconditions: []
steps:
- Run /simplify (Step 0) to remove dead scaffolding before assimilation
- Move PROJECT_PLAN.md (or equivalent) to docs/plans/assimilated/<date>-<slug>.md
- 'Add a closeout section: date, outcome, and which acceptance criteria were met (tick
  each)'
- Remove triage noise from CLAUDE.md or other meta-docs that referenced the plan
- Collapse .gitignore entries that are now resolved (e.g., squash per-tool lines into
  a single pattern)
- Commit as a single documentation/housekeeping commit
pitfalls:
- Ruff/lint errors surfaced during assimilate gate may be pre-existing; fix them in
  a separate commit to keep blame clean
- A large ruff format pass across many files creates a noisy diff; consider whether
  this matters for git blame before running it
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1925-cairn
superseded_by: null
created_at: '2026-06-11 23:12:50.725545+00:00'
updated_at: '2026-06-11 23:12:50.725545+00:00'
---

# assimilate-plan-closeout

## description

Close out a completed plan by assimilating it into the docs archive with evidence and ticking completion criteria
