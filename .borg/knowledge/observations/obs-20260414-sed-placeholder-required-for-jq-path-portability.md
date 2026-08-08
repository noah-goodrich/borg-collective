---
id: obs-20260414-sed-placeholder-required-for-jq-path-portability
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- jq
- sed
- dotfiles
- path-substitution
- json
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 20:39:24.980935+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260414-sed-placeholder-required-for-jq-path-portability

## content

A versioned JSON settings file cannot contain shell variable references (e.g. $HOME or $DOTFILES_DIR) because JSON has no variable interpolation — the literal string is stored. If jq processes the file before substitution, the resolved path in the merged output will be the placeholder string, silently producing broken config.

## resolution

Pipe the base JSON through 'sed s|__DOTFILES_DIR__|$ACTUAL_PATH|g' before passing to jq. This keeps the file valid JSON with a clearly-named placeholder, and the substitution always happens before parsing.
