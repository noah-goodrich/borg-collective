---
id: 20260709-bash-source-zsh-compat
date: '2026-07-09'
project: borg-collective
domain: code-quality
tags:
- bash
- zsh
- BASH_SOURCE
- source
- portability
alternatives: []
applies_to: []
confidence: 0.9
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260709-1659-borg-collective
created_at: '2026-07-09 17:01:17.384310+00:00'
updated_at: '2026-07-09 17:01:17.384311+00:00'
---

# 20260709-bash-source-zsh-compat

## decision

Use ${BASH_SOURCE[0]:-$0} instead of ${BASH_SOURCE[0]} when a file may be sourced by both bash and zsh.

## context

lib/borg-hooks.sh sourced reaper.sh via dirname ${BASH_SOURCE[0]}, but two zsh binaries also source it. BASH_SOURCE is unset in zsh, producing 'no such file or directory: /reaper.sh'.

## reasoning

BASH_SOURCE does not exist in zsh; falling back to $0 gives the correct path when the file is sourced as a zsh script. Pattern is safe in both contexts.
