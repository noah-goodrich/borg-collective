---
id: 20260611-scaffold-basename-no-resolve
date: '2026-06-11'
project: borg-collective
domain: code-quality
tags:
- zsh
- drone
- scaffold
- parameter-expansion
alternatives: []
applies_to: []
confidence: 0.9
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 22:41:19.326304+00:00'
updated_at: '2026-06-11 22:41:19.326305+00:00'
---

# 20260611-scaffold-basename-no-resolve

## decision

Compute workspace basename from the raw input string via zsh parameter expansion rather than resolving to an absolute path before extracting the basename.

## context

cmd_scaffold needed the project basename to set a default workspace path. The initial fix resolved the path to absolute first, which required mkdir -p and preflight to have already run — creating an ordering dependency.

## reasoning

Parameter expansion (e.g. ${input:t} or equivalent) works on the raw string without touching the filesystem, so it can run before any side effects. This breaks the circular dependency between 'need the name' and 'need the dir to exist'.
