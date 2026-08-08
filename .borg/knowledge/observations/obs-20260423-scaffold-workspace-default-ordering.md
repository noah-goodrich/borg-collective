---
id: obs-20260423-scaffold-workspace-default-ordering
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- drone
- scaffold
- preset
- flag-precedence
- bash
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.322970+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260423-scaffold-workspace-default-ordering

## content

The workspace default in `cmd_scaffold` must be set *after* the preset check, not before. If the default is assigned before presets are applied, a preset that sets workspace will be overwritten by the default. The `workspace_explicit` flag is needed to distinguish 'user passed --workspace' from 'default was applied', so presets can override the default but not an explicit user flag.

## resolution

Order of precedence must be: explicit CLI flag > preset value > computed default. Implement with an `workspace_explicit` boolean: set it true only when `--workspace` is parsed from argv; apply preset values only when `!workspace_explicit`; apply the `/workspaces/<project>` default last, only when workspace is still unset.
