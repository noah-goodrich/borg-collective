---
id: obs-20260423-container-volume-paths-pollute-host-claude-md
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- devcontainer
- claude-md
- path-pollution
- borg-setup
- hooks
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.314355+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260423-container-volume-paths-pollute-host-claude-md

## content

borg-start.sh was running CLAUDE.md sync and VS Code extension install inside containers, which wrote container-internal paths (e.g., /home/dev/...) into the host's CLAUDE.md. This corrupted the host CLAUDE.md with paths that don't exist on the host.

## resolution

Added /.dockerenv guard to borg-start.sh to skip CLAUDE.md sync and extension install when running inside a container. Same /.dockerenv sentinel pattern as notify.sh.
