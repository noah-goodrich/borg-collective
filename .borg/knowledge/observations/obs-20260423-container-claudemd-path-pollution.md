---
id: obs-20260423-container-claudemd-path-pollution
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- devcontainer
- docker
- claude-md
- borg-setup
- path-pollution
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 20:39:25.116572+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260423-container-claudemd-path-pollution

## content

Running borg-start.sh inside a devcontainer (where HOME=/home/dev) caused _borg_merge_claude_md to write container-relative paths (/home/dev/...) into the host's CLAUDE.md, corrupting it for host-side Claude sessions.

## resolution

Add a /.dockerenv guard to borg-start.sh (and any setup script that writes to CLAUDE.md or installs extensions) so those steps are skipped entirely when running inside a container.
