---
id: borg-state-branch-handoff
project: cairn
domain: session-management
tags:
- borg
- git
- handoff
- checkpoint
preconditions: []
steps:
- 'Create a dated chore branch: `chore/borg-state-YYYY-MM-DD`.'
- 'Commit only borg-owned files: checkpoint markdown, handoff docs, deleted placeholder
  checkpoints.'
- Explicitly enumerate files that belong to the feat branch (untracked or uncommitted
  there) and do NOT stage them on the borg-state branch.
- Open a separate PR for the borg-state branch; merge independently of the feat branch.
pitfalls:
- Accidentally staging feat-branch files (e.g. `.borg-project` deletion, `.gitignore`
  changes) on the borg-state branch pollutes history and creates merge conflicts.
- Untracked files like `.claude/` must be gitignored rather than committed to either
  branch.
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1925-cairn
superseded_by: null
created_at: '2026-06-11 20:31:18.008500+00:00'
updated_at: '2026-06-11 20:31:18.008501+00:00'
---

# borg-state-branch-handoff

## description

Pattern for committing borg session state on a dedicated branch without contaminating the feature branch or main.
