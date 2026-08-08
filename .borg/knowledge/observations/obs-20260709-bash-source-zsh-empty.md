---
id: obs-20260709-bash-source-zsh-empty
session_date: '2026-07-09'
project: borg-collective
tool: claude-code
tags:
- bash
- zsh
- BASH_SOURCE
- source
- path-resolution
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260709-1659-borg-collective
superseded_by: null
created_at: '2026-07-09 17:01:17.386237+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260709-bash-source-zsh-empty

## content

BASH_SOURCE[0] is unset (empty string) when a script is sourced by zsh. Using it unguarded in $(dirname ${BASH_SOURCE[0]}) produces an empty dirname, resolving relative paths against / instead of the script's actual directory. The error appears as 'no such file or directory: /filename.sh' with the path at filesystem root.

## resolution

Use ${BASH_SOURCE[0]:-$0} everywhere a file may be sourced by both bash and zsh. $0 gives the correct path in the zsh sourcing case.
