---
id: obs-20260527-subshell-fork-in-hot-path
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- bash
- shell
- performance
- parameter-expansion
category: performance
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.495034+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260527-subshell-fork-in-hot-path

## content

$(dirname $sf) was used in the PROJ_DIR resolution block that runs on every hook invocation. dirname is an external process; each call forks a subshell. With multiple hooks firing per Claude session event, this adds measurable latency on systems where fork is expensive (e.g., macOS with SIP, WSL1).

## resolution

Replaced with ${sf%/*} bash parameter expansion, which performs the same path truncation in-process with no fork. Applied consistently in the new _borg_resolve_proj_dir helper so all hook invocations benefit.
