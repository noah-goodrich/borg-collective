---
id: obs-20260616-bash-guard-unhandled-node-type-string
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- bash-guard
- borg-link
- for-loop
- shell-parsing
- permission-prompt
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.334175+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260616-bash-guard-unhandled-node-type-string

## content

bash-guard.sh emits 'Unhandled node type: string' errors and triggers permission prompts when it encounters for-loops iterating over glob patterns like `for f in */docs/plans/*`. The AST parser in bash-guard does not handle bare string glob tokens as loop iterables.

## resolution

Added explicit pre-approval in Layer 1.5 of bash-guard.sh for the two known-safe patterns. Also documented grep/awk/ls alternatives to for-loops in SKILL.md as a forward-avoidance strategy.
