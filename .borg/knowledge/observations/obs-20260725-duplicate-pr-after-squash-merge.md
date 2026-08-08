---
id: obs-20260725-duplicate-pr-after-squash-merge
session_date: '2026-07-25'
project: borg-collective
tool: github
tags:
- git
- github
- squash-merge
- housekeeping
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: null
superseded_by: null
created_at: '2026-07-25 16:56:41.544092+00:00'
updated_at: '2026-07-25 17:54:08.585417+00:00'
---

# obs-20260725-duplicate-pr-after-squash-merge

## content

After squash-merging PR #89 from branch feat/usage-guardian-dispatch-guard, a duplicate PR #90 from the same branch remained OPEN on GitHub. The branch content was already on main via the squash, making #90 pure cruft — but GitHub did not auto-close it.

## resolution

Must explicitly close the duplicate PR and delete the stale branch: `gh pr close 90 --repo noah-goodrich/borg-collective --delete-branch`. Check for orphaned open PRs after any squash merge that had multiple PRs pointing to the same branch.
