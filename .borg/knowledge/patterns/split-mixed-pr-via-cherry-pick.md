---
id: split-mixed-pr-via-cherry-pick
project: borg-collective
domain: git-workflow
tags:
- git
- cherry-pick
- pr-hygiene
- conflict-resolution
preconditions: []
steps:
- 'Identify the commits that belong to the current PR''s stated purpose: git log --oneline
  <branch>.'
- 'Cross-reference against main to confirm which commits are already present: git
  log --oneline main | grep <message fragment>.'
- 'Create a fresh branch from main: git checkout -b fix/<pr-slug>-clean main.'
- 'Cherry-pick only the commits not already in main, in their original order: git
  cherry-pick <sha1> <sha2> ....'
- 'Verify the resulting diff matches expectations: git diff main.'
- Force-push to the original PR branch (or open a new PR), update the PR title/description
  if scope changed, and merge.
pitfalls:
- Cherry-pick SHA order matters — preserve original commit order to avoid logical
  conflicts.
- If cherry-picked commits touch files that were modified by the already-merged commits,
  expect conflicts; resolve carefully since the merged version is already the source
  of truth in main.
- Update the PR title/description to reflect the narrower scope after dropping commits,
  or reviewers will be confused by the mismatch.
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.477496+00:00'
updated_at: '2026-06-11 22:41:19.477496+00:00'
---

# split-mixed-pr-via-cherry-pick

## description

When a PR contains commits from two separate concerns and one concern has already merged via another PR, produce a clean replacement PR containing only the unmerged commits.
