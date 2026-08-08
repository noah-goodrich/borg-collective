---
id: obs-20260714-bash-redirect-open-precedes-2dev-null
session_date: '2026-07-14'
project: borg-collective
tool: claude-code
tags:
- bash
- redirect
- stderr
- file-open
- 2>/dev/null
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260714-1747-borg-collective
superseded_by: null
created_at: '2026-07-14 17:49:55.810338+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260714-bash-redirect-open-precedes-2dev-null

## content

In bash, `command >> file 2>/dev/null` does NOT suppress errors from opening `file`. Bash opens the redirect target as part of setting up the command's file descriptors *before* the command executes and before `2>/dev/null` takes effect. If `file`'s parent directory does not exist, bash emits an open-error on stderr that escapes the suppression. This is distinct from errors emitted by `command` itself. The fix is `{ command >> file; } 2>/dev/null`, which applies the stderr redirect to the entire group including the open.

## resolution

Wrap the redirect in a brace group: `{ printf ... >> "$path"; } 2>/dev/null`. This makes 2>/dev/null cover both the file-open and the command execution.
