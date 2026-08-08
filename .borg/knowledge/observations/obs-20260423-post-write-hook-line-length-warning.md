---
id: obs-20260423-post-write-hook-line-length-warning
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- git-hooks
- linting
- line-length
- checkpoint
- markdown
category: tool_behavior
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.295593+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260423-post-write-hook-line-length-warning

## content

The post-write hook fires on checkpoint .md files and flags lines exceeding 120 characters, but the session treated it as a warning rather than a hard error. The behavior is ambiguous — it may become a blocking error in future hook updates.

## resolution

Reflow checkpoint files to stay under 120 chars per line at write time, or confirm with the hook maintainer whether this is enforced as error vs. warning. Do not assume warning status is stable.
