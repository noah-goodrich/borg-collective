---
id: obs-20260423-scaffold-workspace-default-order
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- drone
- scaffold
- preset
- workspace
- argument-ordering
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 20:39:25.126132+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260423-scaffold-workspace-default-order

## content

In `cmd_scaffold`, the workspace default must be set AFTER the preset check, not before. If the default is set before preset processing, a preset that specifies a workspace will be silently overridden by the default. The bug manifested as the preset's workspace value being ignored.

## resolution

Moved workspace default assignment to after the preset is loaded. Added `workspace_explicit` flag so the default is only applied when the user did not pass `--workspace` and no preset specified one.
