---
id: borg-assimilate-completion-checklist
project: borg-collective
domain: code-quality
tags:
- borg-assimilate
- pr-lifecycle
- conventions
- documentation
preconditions: []
steps:
- 'Squash-merge the PR to main with a feat(scope): summary commit message'
- Delete the feature branch (remote and local)
- Open the plan document and mark all acceptance criteria [x]
- Add ship date to the plan header
- git mv PROJECT_PLAN.md docs/plans/assimilated/YYYY-MM-DD-<slug>.md
- Commit the archive move to main
- Confirm working tree is clean before closing session
- Update next-session notes with follow-on directive threads parented to the archived
  plan
pitfalls:
- Forgetting to record the ship date makes the archive useless as a timeline reference
- Leaving PROJECT_PLAN.md in root after merge causes confusion about whether a plan
  is active
- Skipping the parent-link in follow-on directives breaks the traceability chain
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.528841+00:00'
updated_at: '2026-06-11 22:41:19.528841+00:00'
---

# borg-assimilate-completion-checklist

## description

End-of-plan ritual when a /borg-assimilate target merges: squash-merge branch, delete branch, check all criteria, add ship date, move plan file from root to docs/plans/assimilated/, verify clean working tree.
