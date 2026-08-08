---
id: obs-20260611-host-absolute-path-in-settings-json
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- devcontainer
- settings.json
- plugin-marketplace
- host-path
- container
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.219128+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-host-absolute-path-in-settings-json

## content

`~/.claude/settings.json` line 227 contains a host-absolute path `/Users/noah/.config/dotfiles/claude/plugins` for the plugin marketplace. This path does not exist inside devcontainers, silently breaking plugin resolution. Identified as a blocker for Session 2.


## resolution

Add a host-path compatibility symlink during devcontainer postStartCommand, or rewrite the path to a container-stable location. Fix tracked in `drone.zsh` postStartCommand scaffold for Session 2.

