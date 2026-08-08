---
id: obs-20260416-portfolio-directive-stale-after-rename
session_date: '2026-04-16'
project: borg-collective
tool: cursor
tags:
- borg-collective
- portfolio
- directive
- wallpaper-kit
- reveal
- rename
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.248989+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260416-portfolio-directive-stale-after-rename

## content

The borg-collective portfolio directive (2026-04-14-portfolio-mvp-pivot.md) still referred to the project as wallpaper-kit and listed the rename as a pending blocker, even though reveal had been the live name for some time and was Active. This created a second vector for the same under-reading: portfolio-level planning would deprioritise reveal based on a blocker that no longer existed.

## resolution

When a project is renamed, update the portfolio directive in the same commit or immediately after. Directives in parent/portfolio repos are easy to forget and can silently propagate stale state across sessions.
