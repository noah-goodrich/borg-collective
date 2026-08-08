---
id: obs-20260611-reaper-dual-env-sync-risk
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- borg
- reaper
- bash
- zsh
- hooks
- sync
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.513698+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-reaper-dual-env-sync-risk

## content

The borg reaper logic must exist in two separate files (lib/registry.zsh for CLI, lib/borg-hooks.sh for hooks) because they run in different shell environments. These can silently diverge if one is updated without the other.

## resolution

Treat lib/registry.zsh and lib/borg-hooks.sh reaper definitions as a synchronized pair. Any change to reaper logic must be applied to both files. Consider a comment header in each pointing to the other.
