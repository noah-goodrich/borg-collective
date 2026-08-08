---
id: drone-up-with-prerunning-supabase-stack
project: borg-collective
domain: infrastructure
tags:
- drone
- devcontainer
- supabase
- idempotent
- pre-up-hook
preconditions: []
steps:
- Run `drone up <project>` (e.g., `drone up ingle`)
- '`pre-up.sh` executes `supabase start` — detects containers already up, exits cleanly
  as no-op'
- Devcontainer attaches to `supabase_network_<project>` (already exists)
- Confirm health by running `docker ps` and checking all expected containers show
  status `Up`
- 'Verify expected containers: `supabase_db_<project>`, `supabase_kong_<project>`,
  `supabase_studio_<project>`, etc. (13 total for standard stack)'
pitfalls:
- '`supabase start` appearing to ''succeed'' silently can mask a case where it did
  nothing vs. where it actually started containers — always confirm with `docker ps`
  rather than trusting hook exit code alone'
- If the network exists but containers are unhealthy, the devcontainer may attach
  successfully but the stack is broken — the `docker ps` health check is the real
  gate
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.261154+00:00'
updated_at: '2026-06-11 22:41:19.261154+00:00'
---

# drone-up-with-prerunning-supabase-stack

## description

Running `drone up <project>` when the target project's Supabase stack is already running. The `pre-up.sh` hook calls `supabase start`, which is a no-op against a live stack; the devcontainer reattaches to the existing named network.
