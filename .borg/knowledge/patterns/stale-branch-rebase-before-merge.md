---
id: stale-branch-rebase-before-merge
project: borg-collective
domain: code-quality
tags:
- git
- rebase
- stale-commits
- pr-cleanup
preconditions: []
steps:
- Identify which commits on the branch are still relevant vs. superseded by later
  work
- Run `git rebase -i <base>` and mark stale commits as `drop`
- Verify the resulting branch still passes tests
- Merge the cleaned branch to main
- Delete the local branch after merge
pitfalls:
- Dropping commits that other branches depend on will cause conflicts downstream —
  check for dependents first
- Force-pushing the rebased branch overwrites remote history; coordinate with any
  collaborators before doing so
- Stale commits are not always obviously labelled — read commit messages against current
  code to confirm supersession
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.449043+00:00'
updated_at: '2026-06-16 10:27:02.449044+00:00'
---

# stale-branch-rebase-before-merge

## description

When a long-lived branch has accumulated stale or superseded commits (e.g. from earlier iterations of a feature), interactively rebase to drop those commits before merging to main. Apply to PRs #21, #22, #23 pattern where 3–10 stale commits were dropped per branch.
