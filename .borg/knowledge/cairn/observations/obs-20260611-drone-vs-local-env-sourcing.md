---
id: obs-20260611-drone-vs-local-env-sourcing
session_date: '2026-06-11'
project: cairn
tool: cursor
tags:
- drone
- ci
- secrets
- environment
- local-dev
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1925-cairn
superseded_by: null
created_at: '2026-06-11 23:12:50.726567+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-drone-vs-local-env-sourcing

## content

The Drone CI pipeline sources secrets.zsh but local development relies on local.zsh to export POSTGRES_PASSWORD. These are different files; a developer who only runs CI and doesn't source local.zsh will hit the empty-password bug locally. The two sourcing paths are easy to conflate because they look similar.

## resolution

The .env file approach removes the dependency on any particular shell file being sourced, making local and CI behavior consistent.
