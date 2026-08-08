---
id: obs-20260611-container-hook-path-pollution
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- devcontainer
- hooks
- claude-md
- paths
- borg-start
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 20:39:25.101670+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-container-hook-path-pollution

## content

borg-start.sh ran inside devcontainers and executed CLAUDE.md sync logic, writing container-internal paths (/home/dev/...) into the host's CLAUDE.md. This silently corrupted the host config — the file existed and looked valid but contained wrong paths that would break host-side tooling.

## resolution

Added /.dockerenv guard at the top of the CLAUDE.md sync section in borg-start.sh; the block is skipped entirely when running inside a container.
