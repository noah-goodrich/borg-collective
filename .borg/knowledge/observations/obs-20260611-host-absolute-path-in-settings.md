---
id: obs-20260611-host-absolute-path-in-settings
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- devcontainer
- container
- path
- settings.json
- plugin-marketplace
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 20:39:24.968893+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-host-absolute-path-in-settings

## content

`~/.claude/settings.json` line 227 contains a host-absolute path `/Users/noah/.config/dotfiles/claude/plugins` for the plugin marketplace. This path does not exist inside containers, silently breaking plugin availability for any drone running in a devcontainer.

## resolution

Identified but not yet fixed (queued for Session 2). Planned approach: add a host-path compatibility symlink in the postStartCommand / devcontainer scaffold so the container path resolves correctly.
