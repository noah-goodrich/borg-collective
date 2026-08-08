---
id: obs-20260611-deployed-hook-sync-check
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- borg-collective
- borg-setup
- deployment
- hooks
- diff
category: pattern_discovered
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.487191+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-deployed-hook-sync-check

## content

After running borg setup to deploy updated hooks, the session used diff ~/.claude/hooks/borg-link-down.sh <repo>/hooks/borg-link-down.sh to confirm the live deployed file matched the repo source. This is a cheap but reliable sanity check that setup actually copied the new version.

## resolution

Make this diff check a routine step after any borg setup invocation during development. Consider adding it as a post-setup verification step in the install.sh output or a dedicated borg verify command.
