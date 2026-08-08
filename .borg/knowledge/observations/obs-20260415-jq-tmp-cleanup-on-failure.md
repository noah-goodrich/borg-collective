---
id: obs-20260415-jq-tmp-cleanup-on-failure
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- jq
- shell
- error-handling
- tmp-file
- cleanup
category: error_encountered
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 20:39:25.007885+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260415-jq-tmp-cleanup-on-failure

## content

Initial implementation of the jq merge helper did not clean up the tmp file on jq failure. A failed merge would leave an empty or partial JSON file at the tmp path, silently poisoning a subsequent run that reused the same tmp filename.

## resolution

Fixed by appending `|| { rm -f "$tmp"; return 1; }` immediately after the jq invocation. The pattern is: write to tmp, guard cleanup on failure, then mv to final destination.
