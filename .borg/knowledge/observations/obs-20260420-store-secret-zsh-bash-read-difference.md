---
id: obs-20260420-store-secret-zsh-bash-read-difference
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- zsh
- bash
- secrets
- dev-tools
- shell-compatibility
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.193107+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260420-store-secret-zsh-bash-read-difference

## content

The dev-tools:store-secret skill uses `read -s -p` which is bash syntax. In zsh, `read -p` treats the argument as a variable name to read into (not a prompt string), causing the prompt flag to be parsed differently and potentially storing incorrect values silently.

## resolution

When invoking store-secret from a zsh session, verify behavior. Fix the skill to use zsh-compatible syntax (`read -s '?prompt: ' varname`) or add a shell-detection guard. Filed as a latent bug — not yet fixed.
