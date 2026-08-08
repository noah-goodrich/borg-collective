---
id: obs-20260616-stray-dev-root-accumulation
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- housekeeping
- dev-directory
- session-files
- drift
category: pattern_discovered
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.429844+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260616-stray-dev-root-accumulation

## content

The ~/dev/ root accumulated 5 stray session markdown files, a 102M brand asset directory, and orphaned repo clones between sessions. This is a recurring drift pattern: work that 'lands somewhere temporarily' during a session never gets routed if there is no explicit cleanup step.

## resolution

The ~/dev audit directive was added as an explicit periodic task. The pattern of adding a 'route deferred files' item to the next-session checklist (as done in section 5 of this checkpoint) prevents accumulation. Large binary assets (snowflake_assets at 102M) should be moved to ~/Documents immediately rather than staged in ~/dev.
