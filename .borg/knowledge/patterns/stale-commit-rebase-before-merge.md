---
id: stale-commit-rebase-before-merge
project: borg-collective
domain: code-quality
tags:
- git
- rebase
- branch-hygiene
- pr-merge
- stale-commits
preconditions: []
steps:
- Identify which commits on the branch are still relevant vs. superseded by later
  work on main
- Run git rebase -i <merge-base> and drop stale commits (e.g. borg-plan-promote commits
  already landed via another PR)
- Verify the remaining commits apply cleanly and tests pass
- Open or update the PR with the cleaned branch
- Merge — history is clean and reviewable without the noise
pitfalls:
- Dropping commits that were actually still needed (check each dropped commit's diff
  against current main before dropping)
- Force-pushing a shared branch that others have checked out — coordinate first
- Stale commits from a different feature area can look harmless but may reintroduce
  removed code — always diff after rebase
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.485678+00:00'
updated_at: '2026-06-11 22:41:19.485678+00:00'
---

# stale-commit-rebase-before-merge

## description

When a long-lived branch has accumulated stale or superseded commits alongside good ones, interactively rebase to drop the stale commits before merging, rather than squash-merging or force-pushing the whole branch.
