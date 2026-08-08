---
id: obs-20260611-live-env-separate-from-repo
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- hooks
- live-environment
- settings-json
- installation
- claude
- snowflake
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 20:39:25.161577+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-live-env-separate-from-repo

## content

Hooks and settings exist in at least three separate live locations independent of the repo: `~/.claude/settings.json`, `~/.snowflake/cortex/settings.json`, and installed hook files in both dirs. After any hook rename or settings change in the repo, all three live locations must be updated manually and verified with `jq empty`. It's easy to update the repo and forget the live env, leaving the running system on stale hook names.

## resolution

After content swap, explicitly install hooks to each live dir and re-verify all three settings JSONs with `jq`. Consider automating this in install.sh.
