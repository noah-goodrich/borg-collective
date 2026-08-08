---
id: dangling-symlink-before-cp
project: borg-collective
domain: code-quality
tags:
- borg.zsh
- symlink
- cp
- setup
preconditions: []
steps:
- 'Before cp src dst, check: if [[ -L "$dst" && ! -e "$dst" ]]; then rm "$dst"; fi'
- Proceed with cp normally
pitfalls:
- cp does not error on a dangling symlink — it 'succeeds' but the file ends up at
  the symlink's dead target, not at $dst
- -L tests for symlink existence (true even if dangling); -e tests for resolved target
  existence (false if dangling); combining them identifies exactly the dangling case
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 20:39:25.100017+00:00'
updated_at: '2026-06-11 20:39:25.100018+00:00'
---

# dangling-symlink-before-cp

## description

Detect and remove a dangling symlink at a target path before attempting cp, to prevent cp from silently writing through the symlink to a nonexistent destination
