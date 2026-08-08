---
id: obs-20260611-container-claude-md-pollution
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- devcontainer
- CLAUDE.md
- hooks
- paths
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.304273+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-container-claude-md-pollution

## content

borg-start.sh was running CLAUDE.md sync and extension installation inside devcontainers. The container has a different HOME (/home/dev/...) than the host, so container-origin path writes polluted the host's CLAUDE.md with container-specific absolute paths that are invalid on the host.

## resolution

Added /.dockerenv guard at the top of the CLAUDE.md sync and extension blocks in borg-start.sh to silently skip those operations inside containers.
