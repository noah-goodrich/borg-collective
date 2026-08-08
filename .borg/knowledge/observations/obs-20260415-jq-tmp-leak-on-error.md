---
id: obs-20260415-jq-tmp-leak-on-error
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- jq
- zsh
- tmp-files
- error-handling
- settings-management
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.232023+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260415-jq-tmp-leak-on-error

## content

The initial implementation of _borg_merge_settings_permissions did not guard against jq failure. If jq errored mid-execution, the tmp file was written but never cleaned up, leaving stale files on disk. This is invisible during happy-path testing.

## resolution

Fixed in refactor commit by appending || { rm -f "$tmp"; return 1; } to every jq invocation in the function. Any future jq additions in this function require the same pattern — it is not automatic.
