---
id: obs-20260715-symlink-deploy-instant
session_date: '2026-07-15'
project: borg-collective
tool: claude-code
tags:
- deployment
- symlink
- borg-usage-watch
- live-poller
category: tool_behavior
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260715-0256-borg-collective
superseded_by: null
created_at: '2026-07-15 02:57:12.429363+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260715-symlink-deploy-instant

## content

The live poller at /Users/noah/.local/bin/borg-usage-watch is a symlink into the source repository. Merging a fix to main immediately takes effect for the running poller with no install step required. This is both a convenience and a risk: a broken commit to main is instantly live.

## resolution

No change needed, but future sessions should be aware: any change to bin/borg-usage-watch is immediately deployed to the production poller upon merge. Test thoroughly before merging, not just after.
