---
id: obs-20260527-dirname-subprocess-vs-parameter-expansion
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- bash
- shell
- performance
- parameter-expansion
category: domain_knowledge
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.457923+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260527-dirname-subprocess-vs-parameter-expansion

## content

$(dirname "$sf") forks a subshell and execs dirname to strip the last path component. The pure-bash equivalent ${sf%/*} does the same thing without any subprocess. In hooks that run on every session attach/detach this is a meaningful difference, and the parameter expansion form is more portable across bash versions.

## resolution

Replace $(dirname ...) with ${sf%/*} in shell scripts where the value is a file path and the goal is the parent directory. Be aware ${sf%/*} returns the original string unchanged if there is no / (whereas dirname returns '.'), so guard if that edge case matters.
