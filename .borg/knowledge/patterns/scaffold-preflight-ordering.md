---
id: scaffold-preflight-ordering
project: borg-collective
domain: testing
tags:
- zsh
- drone
- scaffold
- bats
- preflight
preconditions: []
steps:
- Parse the sub-command flag first (e.g. --supabase).
- Dispatch to the sub-command handler (_cmd_scaffold_supabase, etc.).
- Inside the sub-command handler, run _scaffold_preflight (checks .devcontainer/ doesn't
  exist) and mkdir -p as the first actions.
- If you need a basename or other derived value before the branch, compute it via
  parameter expansion on the raw input — do not touch the filesystem to derive it.
pitfalls:
- Moving shared preflight before the branch to gain access to a derived value (like
  basename) will cause the sub-command's internal preflight to find the directory
  already created and fail.
- The failure manifests as an error inside the sub-command, not at the shared preflight
  site, making the root cause non-obvious.
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 20:39:25.137438+00:00'
updated_at: '2026-06-11 20:39:25.137439+00:00'
---

# scaffold-preflight-ordering

## description

Ordering rule for scaffold commands that have sub-commands with their own preflight checks: shared setup (preflight + mkdir) must come AFTER the sub-command branch, not before.
