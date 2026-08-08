---
id: obs-20260714-xdg-config-home-bleeds-through-home-override
session_date: '2026-07-14'
project: borg-collective
tool: claude-code
tags:
- bats
- xdg
- HOME
- environment
- test-isolation
- borg
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260714-1747-borg-collective
superseded_by: null
created_at: '2026-07-14 17:49:55.812195+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260714-xdg-config-home-bleeds-through-home-override

## content

Overriding HOME in a bats setup() function does not override XDG_CONFIG_HOME. If the developer's shell has XDG_CONFIG_HOME set (common on systems using XDG-compliant setups), tools that compute their config directory via `${XDG_CONFIG_HOME:-$HOME/.config}` will still resolve to the real XDG_CONFIG_HOME — which likely points to a path that doesn't exist in the test sandbox. This causes derived paths (e.g., BORG_DIR) to be wrong, silently causing the tool to operate on non-existent directories.

## resolution

In bats setup(), explicitly set `export XDG_CONFIG_HOME="$HOME/.config"` immediately after setting HOME. This ensures the derived path follows the test HOME rather than the outer environment.
