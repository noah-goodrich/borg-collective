---
id: 20260611-basename-before-preflight
date: '2026-06-11'
project: borg-collective
domain: code-quality
tags:
- zsh
- drone
- scaffold
- ordering
- parameter-expansion
alternatives: []
applies_to: []
confidence: 0.9
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 20:39:25.136052+00:00'
updated_at: '2026-06-11 20:39:25.136052+00:00'
---

# 20260611-basename-before-preflight

## decision

Compute workspace basename from the raw input string via parameter expansion before running preflight checks, rather than resolving to an absolute path first.

## context

cmd_scaffold needed the project basename to set a default workspace path. The naive fix moved _scaffold_preflight and mkdir -p up before the --supabase branch so the basename was available, but that caused the supabase sub-command's internal preflight to fail because .devcontainer/ already existed when it ran.

## reasoning

Parameter expansion (e.g. ${input##*/}) on the raw input string is sufficient to get the basename without touching the filesystem. This keeps preflight and directory creation in their correct post-branch position, preserving the invariant that .devcontainer/ does not exist when _cmd_scaffold_supabase runs its own preflight.
