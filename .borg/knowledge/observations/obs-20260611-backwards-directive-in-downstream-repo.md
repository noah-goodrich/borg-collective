---
id: obs-20260611-backwards-directive-in-downstream-repo
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- claude-plugins
- repo-ownership
- source-of-truth
- drift
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.461156+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-backwards-directive-in-downstream-repo

## content

claude-plugins contained a directive that implied it was the canonical source and borg-collective should sync from it — the opposite of the intended architecture. This went unnoticed until the original Dispatch session was located.

## resolution

Fixed the directive in claude-plugins to correctly describe it as a downstream distribution. Added explicit source-of-truth statement to borg-collective handoff doc. Future sessions should treat any claude-plugins directive about borg-collective with suspicion and verify against session f9ef8d07.
