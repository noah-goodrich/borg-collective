---
id: obs-20260630-shell-string-truthiness-zero
session_date: '2026-06-30'
project: borg-collective
tool: claude-code
tags:
- shell
- zsh
- bash
- boolean
- variable-expansion
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260630-2202-borg-collective
superseded_by: null
created_at: '2026-06-30 22:03:12.819762+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260630-shell-string-truthiness-zero

## content

In shell, `${var:+something}` treats the string '0' as set/truthy (because it's non-empty), not as false. A variable holding '0' to mean 'disabled' will still expand the truthy branch. Found in `borg-vinculum-watch` around line 160 where `${_once_mode:+ once}` incorrectly logged 'once' even in persistent mode when `_once_mode=0`.

## resolution

Use arithmetic conditional `(( _once_mode ))` instead of `${var:+...}` when the variable is an integer flag where 0 means false. Reserve `${var:+...}` for string presence checks where the empty string means unset/false.
