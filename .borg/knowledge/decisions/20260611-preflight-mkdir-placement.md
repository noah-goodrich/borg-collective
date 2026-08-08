---
id: 20260611-preflight-mkdir-placement
date: '2026-06-11'
project: borg-collective
domain: architecture
tags:
- zsh
- drone
- scaffold
- preflight
- ordering
alternatives: []
applies_to: []
confidence: 0.9
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 22:41:19.326704+00:00'
updated_at: '2026-06-11 22:41:19.326705+00:00'
---

# 20260611-preflight-mkdir-placement

## decision

Keep _scaffold_preflight and mkdir -p dc_dir AFTER the --supabase branch dispatch, not before it.

## context

Moving them before the branch was intended to DRY up initialization, but supabase's subcommand runs its own internal preflight and the directory already existing caused it to abort.

## reasoning

Each branch owns its own preflight preconditions. Hoisting shared setup above branching only works when the setup is truly idempotent and all branches tolerate it; here the supabase branch explicitly checks for directory non-existence.
