---
id: obs-20260713-slash-pollution-root-cause
session_date: '2026-07-13'
project: cairn
tool: claude-code
tags:
- call_log
- usage-stats
- launchd
- session-hooks
- pollution
- cwd
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260713-2223-cairn
superseded_by: null
created_at: '2026-07-13 22:50:48.701202+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260713-slash-pollution-root-cause

## content

The usage-watch launchd poller (borg-collective/bin/borg-usage-watch:157) spawns 'claude -p "/usage"' with cwd='/' every 2 minutes. The SessionStart hook interprets the cwd as the project context and runs 'cairn search "/"', logging a synthetic '/' row to call_log. This caused 80% of all call_log rows (762/953 over 5 days) to be '/' pollution, collapsing the apparent ROI retrieval rate from ~52% to ~2%.

## resolution

Two-pronged fix: (1) cairn PR #24 excludes query='/' and skipped rows from get_usage_stats; (2) borg PR #75 adds BORG_NO_SESSION_HOOKS env var mute and a cwd='/' guard to prevent the hook from firing for synthetic poller sessions in the first place.
