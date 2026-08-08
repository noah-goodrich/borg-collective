---
id: obs-20260611-preflight-ordering-regression
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- zsh
- drone
- scaffold
- bats
- preflight
- ordering
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 20:39:25.137866+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-preflight-ordering-regression

## content

Moving _scaffold_preflight and mkdir -p earlier in cmd_scaffold (before the --supabase branch dispatch) to access the computed workspace basename caused all 10 scaffold_supabase.bats tests to fail. The sub-command _cmd_scaffold_supabase runs its own preflight check that asserts .devcontainer/ does not exist; because the shared mkdir had already created it, every test hit that assertion.

## resolution

Compute the workspace basename purely via zsh parameter expansion on the raw input string (no filesystem access needed). Keep _scaffold_preflight and mkdir in their original post-branch position inside each sub-command handler.
