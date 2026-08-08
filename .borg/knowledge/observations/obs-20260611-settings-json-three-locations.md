---
id: obs-20260611-settings-json-three-locations
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- settings-json
- live-env
- hooks
- claude
- snowflake
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.335439+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-settings-json-three-locations

## content

Hook registrations exist in at least three separate settings.json files: `config/claude/settings.base.json` (repo canonical), `~/.claude/settings.json` (Claude live env), and `~/.snowflake/cortex/settings.json` (CoCo live env). Updating only the repo file leaves the live environments running stale hook scripts pointing to the old filenames — the swap appears to work in CI/tests but fires the wrong hook at runtime.

## resolution

After updating the base config, explicitly update and verify all three live settings files with `jq`. In this session all three were patched and verified before the bats run.
