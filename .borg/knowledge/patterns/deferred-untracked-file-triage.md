---
id: deferred-untracked-file-triage
project: borg-collective
domain: git-workflow
tags:
- git
- gitignore
- housekeeping
- untracked-files
preconditions: []
steps:
- Run git status to enumerate all untracked files
- 'Categorize each file: belongs in repo, belongs in gitignore, or belongs outside
  repo entirely'
- 'For files belonging in repo: stage and commit with meaningful groupings (scripts
  together, tests together, docs together)'
- 'For files that should be ignored: add to .gitignore and verify no negation rules
  are broken (see pitfall)'
- 'For files outside repo scope: move to appropriate location (archive dir, external
  repo, etc.)'
- Open single PR with all routing decisions documented in the PR description
pitfalls:
- 'Negation rules in .gitignore break silently: if you add a positive ignore rule
  (e.g., .borg/) that covers a path with an existing negation rule (!.borg/checkpoints/),
  the negation stops working. Always audit surrounding negation rules when adding
  new ignore patterns.'
- Session checkpoint files may be untracked intentionally — confirm they should be
  committed before staging
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.428995+00:00'
updated_at: '2026-06-16 10:27:02.428995+00:00'
---

# deferred-untracked-file-triage

## description

Batch-routes accumulated untracked files that were deferred from a previous session into their correct homes in a single cleanup PR
