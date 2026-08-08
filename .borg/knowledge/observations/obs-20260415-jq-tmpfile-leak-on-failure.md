---
id: obs-20260415-jq-tmpfile-leak-on-failure
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- zsh
- jq
- tmp-files
- error-handling
- shell-scripting
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 20:39:24.989878+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260415-jq-tmpfile-leak-on-failure

## content

The initial implementation of _borg_merge_settings_permissions created a tmp file via mktemp but did not guard the jq call with || { rm -f "$tmp"; return 1; }. Any jq failure (malformed input, bad filter, permission error) left a stale tmp file in /tmp and the function returned success or an ambiguous exit code. The bug was silent — no error message, no cleanup, and the target settings file was left unmodified while tmp files accumulated.

## resolution

Added || { rm -f "$tmp"; return 1; } immediately after every jq invocation in the function. The fix was included in the refactor commit. Every future jq addition to this function needs the same guard — this is a recurring pitfall, not a one-time fix.
