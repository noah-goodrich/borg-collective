---
id: two-file-swap-via-intermediate
project: borg-collective
domain: infrastructure
tags:
- shell
- file-management
- rename
preconditions: []
steps:
- mv file-A.sh file-A.sh.swap
- mv file-B.sh file-A.sh
- mv file-A.sh.swap file-B.sh
- Verify both files exist and have the expected content before proceeding
pitfalls:
- Forgetting the intermediate leaves one file overwritten and unrecoverable outside
  of git
- If the swap also requires content changes (e.g., flipping header comments), do the
  rename first and content edits second to avoid editing the wrong file
- In a git repo, `git status` will show both files as renamed/modified — confirm both
  appear before staging
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.334709+00:00'
updated_at: '2026-06-11 22:41:19.334709+00:00'
---

# two-file-swap-via-intermediate

## description

Safely swap the names of two files when each must take the other's name, avoiding destructive overwrite.
