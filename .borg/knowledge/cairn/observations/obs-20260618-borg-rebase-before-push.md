---
id: obs-20260618-borg-rebase-before-push
session_date: '2026-06-18'
project: cairn
tool: claude-code
tags:
- git
- rebase
- borg-collective
- multi-repo
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260618-0029-cairn
superseded_by: null
created_at: '2026-06-18 00:30:17.388672+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260618-borg-rebase-before-push

## content

borg-collective required a rebase onto remote (8513c97) before the Layer 1 accrual block commit (93a9e59) could be pushed. The local branch had diverged from remote main, which would have caused a rejected push.

## resolution

Always `git fetch && git rebase origin/main` on borg-collective before pushing hook changes, since other tooling may have pushed to main between sessions. Verify the accrual block content is intact after rebase — it lives in a specific 28-line range of borg-link-up.sh that could conflict with other hook edits.
