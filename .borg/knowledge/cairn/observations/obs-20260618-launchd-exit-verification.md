---
id: obs-20260618-launchd-exit-verification
session_date: '2026-06-18'
project: cairn
tool: claude-code
tags:
- launchd
- macos
- backstop
- monitoring
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260618-0029-cairn
superseded_by: null
created_at: '2026-06-18 00:30:17.387808+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260618-launchd-exit-verification

## content

After `launchctl load`, the plist shows as registered and last exit 0 immediately — but this reflects the load event, not a successful script execution. The actual script has not run yet at registration time. The first real execution happens at the scheduled time (03:00), not at load time.

## resolution

Do not treat load-time exit 0 as proof the extraction script works. Verify by checking the script's own log file (~/.local/state/borg/cairn-inbox/cairn-extract.log) after the first natural 03:00 fire, or by temporarily advancing the schedule for a manual test.
