---
id: obs-20260611-drone-secrets-scope-gap
session_date: '2026-06-11'
project: cairn
tool: cursor
tags:
- drone
- ci
- secrets
- shell-sourcing
- environment-variables
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1925-cairn
superseded_by: null
created_at: '2026-06-11 20:31:18.017818+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-drone-secrets-scope-gap

## content

Drone CI sources `secrets.zsh` but not `local.zsh`. If a variable (like POSTGRES_PASSWORD) is only exported in `local.zsh`, it will be undefined in Drone pipelines. This is a silent gap — no error at the sourcing step, only failures downstream when the variable is consumed.

## resolution

Ensure all variables referenced in compose.yml either have defaults in compose itself, are present in the Drone secrets store, or are exported from a file that Drone explicitly sources. The .env file approach sidesteps the shell-sourcing chain entirely for compose.
