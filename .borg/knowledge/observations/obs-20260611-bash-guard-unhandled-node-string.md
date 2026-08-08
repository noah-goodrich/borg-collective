---
id: obs-20260611-bash-guard-unhandled-node-string
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- bash-guard
- borg-link
- for-loop
- glob
- AST
- shell-parsing
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.421373+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-bash-guard-unhandled-node-string

## content

bash-guard.sh's AST parser emits 'Unhandled node type: string' and falls through to a permission prompt when it encounters a for-loop iterating over a glob pattern (e.g., 'for f in */docs/plans/*'). The parser handles variable expansion and command substitution but not bare string/glob tokens as the loop's word list.

## resolution

Add explicit pre-approval cases in Layer 1.5 for the specific safe glob patterns. The SKILL.md for borg-link was also updated to document grep/awk/ls alternatives that avoid for-loops over globs entirely, which is the longer-term mitigation for new skill authoring.
