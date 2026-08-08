---
id: 20260423-no-borg-link-rename
date: '2026-06-11'
project: borg-collective
domain: architecture
tags:
- borg
- borg-link
- naming
- hooks
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 20:39:25.124354+00:00'
updated_at: '2026-06-11 20:39:25.124355+00:00'
---

# 20260423-no-borg-link-rename

## decision

Do not rename `borg-link-up`/`borg-link-down` hooks. The start hook is never user-invoked (renaming is cosmetic only); `/borg-checkpoint` already serves as the functional 'link-down' equivalent.

## context

There was a proposal to rename hooks for symmetry, but the asymmetry is not a real usability problem.

## reasoning

The rename is pure churn with no behavioral benefit. `/borg-checkpoint` already handles the 'link-down' use case.
