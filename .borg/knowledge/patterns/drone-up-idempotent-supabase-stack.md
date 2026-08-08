---
id: drone-up-idempotent-supabase-stack
project: borg-collective
domain: infrastructure
tags:
- drone
- supabase
- devcontainer
- idempotency
- pre-up-hook
preconditions: []
steps:
- Run `drone up <project>` (e.g., `drone up ingle`)
- '`pre-up.sh` executes `supabase start` — if containers are already up, this is a
  no-op'
- Devcontainer attaches to the existing `supabase_network_<project>` network
- Confirm health by checking all expected containers (db, kong, studio, etc.) show
  'up' in `docker ps`
pitfalls:
- If you expect `supabase start` to reset state (e.g., re-run migrations), it will
  NOT do so against a running stack — you must stop first
- Container health check via `docker ps` is a necessary confirmation step; `drone
  up` success alone doesn't prove the Supabase stack is healthy
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 20:39:25.036184+00:00'
updated_at: '2026-06-11 20:39:25.036184+00:00'
---

# drone-up-idempotent-supabase-stack

## description

Running `drone up <project>` against an already-running Supabase stack is safe and idempotent — the `pre-up.sh` hook's `supabase start` becomes a no-op and the devcontainer reattaches to the existing network.
