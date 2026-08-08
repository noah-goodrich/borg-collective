---
id: 20260420-git-mv-fallback-plain-mv
date: '2026-06-11'
project: borg-collective
domain: code-quality
tags:
- git
- borg
- zsh
- file-operations
- history-preservation
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 20:39:25.082229+00:00'
updated_at: '2026-06-11 20:39:25.082230+00:00'
---

# 20260420-git-mv-fallback-plain-mv

## decision

cmd_start checks git ls-files before moving a directive; uses git mv if tracked, plain mv if untracked.

## context

Directives written mid-session may not yet be committed/tracked. Using git mv on an untracked file errors out.

## reasoning

Preserves git history for tracked directives (important for audit trail) while not breaking the common case of promoting a freshly-written, not-yet-committed directive.
