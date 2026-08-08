---
id: obs-20260611-lib-source-path-mismatch
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- shell
- lib
- sourcing
- path
- silent-failure
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 20:39:24.967700+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-lib-source-path-mismatch

## content

When a lib/ helper file is sourced with an incorrect path (e.g., wrong relative reference), the source silently fails and the calling script falls through to old/broken code. No error is emitted by default in zsh/bash unless `set -e` or explicit error handling is present. This was recorded as a Learned entry in CLAUDE.md.

## resolution

After adding a lib source line, immediately verify with `type <function_name>` to confirm the function loaded. Use absolute paths or paths anchored to `${BASH_SOURCE[0]}` / `${0:A:h}` rather than relative paths.
