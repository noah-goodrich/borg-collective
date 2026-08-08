---
id: obs-20260611-supabase-preflight-double-run
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- zsh
- bats
- scaffold
- preflight
- supabase
- ordering
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.327031+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-supabase-preflight-double-run

## content

Moving shared setup (preflight + mkdir) above the branch dispatcher in cmd_scaffold caused _cmd_scaffold_supabase to fail because .devcontainer/ already existed when the supabase subcommand ran its own internal preflight. The supabase path treats a pre-existing devcontainer dir as a fatal collision. The regression was purely an ordering change — no logic changed — making it easy to miss in review.

## resolution

Moved preflight + mkdir back to after the supabase branch. Computed the needed basename from the raw input string via parameter expansion so no filesystem access was needed before branching.
